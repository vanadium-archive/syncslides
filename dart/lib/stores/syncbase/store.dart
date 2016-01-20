// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library syncbase_store;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:logging/logging.dart';

import '../../discovery/client.dart' as discovery;
import '../../identity/client.dart' as identity;
import '../../loaders/loader.dart';
import '../../models/all.dart' as model;
import '../../settings/client.dart' as settings;
import '../../syncbase/client.dart' as sb;
import '../../utils/errors.dart' as errorsutil;
import '../../utils/uuid.dart' as uuidutil;
import '../store.dart';
import '../utils/key.dart' as keyutil;

part 'actions.dart';
part 'consts.dart';
part 'state.dart';

// Implementation of Store using Syncbase (http://v.io/syncbase) storage system.
class SyncbaseStore implements Store {
  _AppState _state;
  _AppActions _actions;
  StreamController _stateChangeEmitter = new StreamController.broadcast();

  AppState get state => _state;
  Stream get onStateChange => _stateChangeEmitter.stream;
  AppActions get actions => _actions;

  SyncbaseStore() {
    _state = new _AppState();
    _actions = new _AppActions(_state, _triggerStateChange);
  }

  Future init() async {
    // Wait for synchronous initializers.
    await _syncInits();

    // Don't wait for async ones.
    _asyncInits();
  }

  // Initializations that we must wait for before considering store initalized.
  Future _syncInits() async {
    await _createSyncbaseHierarchy();
    _state._user = await identity.getUser();
    _state._settings = await settings.getSettings();
  }

  // Initializations that can be done asynchronously. We do not need to wait for
  // these before considering store initalized.
  Future _asyncInits() async {
    // TODO(aghassemi): Use the multi-table scan and watch API when ready.
    // See https://github.com/vanadium/issues/issues/923
    for (String table in [decksTableName, presentationsTableName]) {
      _getInitialValuesAndStartWatching(table);
    }
    _startScanningForPresentations();
  }

  // Note(aghassemi): We could have copied the state to provide a snapshot at the time of
  // change, however for this application we did not choose to do so because:
  //  1- The state is already publically deeply-immutable, so only store code can mutate it.
  //  2- Although there is a chance by the time UI rerenders due to a change event, the state
  //     may have changed causing UI to skip rendering the intermediate states, it is not an
  //     undesirable behaviour for SyncSlides. This behaviour may not be acceptable for different
  //     categories of apps that require continuity of rendering, such as games.
  void _triggerStateChange() => _stateChangeEmitter.add(_state);

  Future _startScanningForPresentations() async {
    discovery.PresentationScanner scanner = await discovery.scan();

    scanner.onFound.listen((model.PresentationAdvertisement newP) {
      _state._presentationsAdvertisements[newP.key] = newP;
      _triggerStateChange();

      // TODO(aghassemi): Use a simple RPC instead of a syncgroup to get the thumbnail.
      // See https://github.com/vanadium/syncslides/issues/17
      // Join the thumbnail syncgroup to get the thumbnail blob.
      String sgName = newP.thumbnailSyncgroupName;
      sb.joinSyncgroup(sgName);
    });

    scanner.onLost.listen((String presentationId) {
      _state._presentationsAdvertisements.remove(presentationId);
      _state._decks.values.forEach((_DeckState deck) {
        if (deck.presentation != null &&
            deck.presentation.key == presentationId) {
          deck._isPresenting = false;
        }
      });
      _triggerStateChange();
    });
  }

  Future _getInitialValuesAndStartWatching(String table) async {
    // TODO(aghassemi): Ideally we wouldn't need an initial query and can configure
    // watch to give both initial values and future changes.
    // See https://github.com/vanadium/issues/issues/917
    var batchDb = await sb.database
        .beginBatch(sb.SyncbaseClient.batchOptions(readOnly: true));
    var resumeMarker = await batchDb.getResumeMarker();

    // Get initial values in a batch.
    String query = 'SELECT k, v FROM $table';
    Stream<sb.Result> results = batchDb.exec(query);
    // NOTE(aghassemi): First row is always the name of the columns, so we skip(1).
    await results.skip(1).forEach((sb.Result result) => _onChange(
        table,
        sb.WatchChangeTypes.put,
        UTF8.decode(result.values[0]),
        result.values[1]));

    await batchDb.abort();

    // Start watching from batch's resume marker.
    var stream = sb.database.watch(table, '', resumeMarker);
    stream.listen((sb.WatchChange change) =>
        _onChange(table, change.changeType, change.rowKey, change.valueBytes));
  }

  _onChange(String table, int changeType, String rowKey, List<int> value) {
    log.finest('Change in $table for $rowKey of the type $changeType.');

    keyutil.KeyType keyType = keyutil.getKeyType(rowKey);
    switch (keyType) {
      case keyutil.KeyType.Deck:
        _onDeckChange(changeType, rowKey, value);
        break;
      case keyutil.KeyType.Slide:
        _onSlideChange(changeType, rowKey, value);
        break;
      case keyutil.KeyType.PresentationCurrSlideNum:
        _onPresentationSlideNumChange(changeType, rowKey, value);
        break;
      case keyutil.KeyType.PresentationDriver:
        _onPresentationDriverChange(changeType, rowKey, value);
        break;
      case keyutil.KeyType.PresentationQuestion:
        _onPresentationQuestionChange(changeType, rowKey, value);
        break;
      case keyutil.KeyType.Unknown:
        log.severe('Got change for $rowKey with an unknown key type.');
    }
    _triggerStateChange();
  }

  _onDeckChange(int changeType, String rowKey, List<int> value) {
    var deckId = rowKey;
    if (changeType == sb.WatchChangeTypes.put) {
      _state._getOrCreateDeckState(deckId)._deck =
          new model.Deck.fromJson(deckId, UTF8.decode(value));
    } else if (changeType == sb.WatchChangeTypes.delete) {
      _state._decks.remove(deckId);
    }
  }

  _onSlideChange(int changeType, String rowKey, List<int> value) {
    var deckId = keyutil.currSlideKeyToDeckId(rowKey);
    var index = keyutil.currSlideKeyToIndex(rowKey);
    var slides = _state._getOrCreateDeckState(deckId)._slides;
    if (changeType == sb.WatchChangeTypes.put) {
      var slide = new model.Slide.fromJson(UTF8.decode(value));
      slides.add(slide);
    } else if (changeType == sb.WatchChangeTypes.delete) {
      slides.removeWhere((s) => s.num == index);
    }

    // Keep the slides sorted by number.
    slides.sort((model.Slide a, model.Slide b) {
      return a.num.compareTo(b.num);
    });
  }

  _onPresentationSlideNumChange(
      int changeType, String rowKey, List<int> value) {
    String deckId = keyutil.presentationCurrSlideNumKeyToDeckId(rowKey);
    String presentationId =
        keyutil.presentationCurrSlideNumKeyToPresentationId(rowKey);

    _DeckState deckState = _state._getOrCreateDeckState(deckId);
    _PresentationState presentationState =
        deckState._getOrCreatePresentationState(presentationId);

    if (changeType == sb.WatchChangeTypes.put) {
      int currSlideNum = int.parse(UTF8.decode(value));
      presentationState._currSlideNum = currSlideNum;
    } else {
      presentationState._currSlideNum = 0;
    }
  }

  _onPresentationDriverChange(int changeType, String rowKey, List<int> value) {
    String deckId = keyutil.presentationDriverKeyToDeckId(rowKey);
    String presentationId =
        keyutil.presentationDriverKeyToPresentationId(rowKey);

    _DeckState deckState = _state._getOrCreateDeckState(deckId);
    _PresentationState presentationState =
        deckState._getOrCreatePresentationState(presentationId);

    if (changeType == sb.WatchChangeTypes.put) {
      model.User driver = new model.User.fromJson(UTF8.decode(value));
      presentationState._driver = driver;
      log.info('${driver.name} is now driving the presentation.');
    } else {
      presentationState._driver = _state.user;
    }
  }

  _onPresentationQuestionChange(
      int changeType, String rowKey, List<int> value) {
    String deckId = keyutil.presentationQuestionKeyToDeckId(rowKey);

    _DeckState deckState = _state._getOrCreateDeckState(deckId);
    _PresentationState presentationState = deckState.presentation;
    if (presentationState == null) {
      return;
    }

    String questionId = keyutil.presentationQuestionKeyToQuestionId(rowKey);

    if (changeType == sb.WatchChangeTypes.put) {
      model.Question question =
          new model.Question.fromJson(questionId, UTF8.decode(value));
      presentationState._questions.add(question);
    } else {
      presentationState._questions
          .removeWhere((model.Question q) => q.id == questionId);
    }

    // Keep questions sorted by timestamp.
    presentationState._questions.sort((model.Question a, model.Question b) {
      return a.timestamp.compareTo(b.timestamp);
    });
  }

  Future<sb.SyncbaseTable> _createTable(String tableName) async {
    sb.SyncbaseTable tb = sb.database.table(tableName);
    try {
      await tb.create(sb.createOpenPerms());
    } catch (e) {
      if (!errorsutil.isExistsError(e)) {
        throw e;
      }
    }
    return tb;
  }

  Future _createSyncbaseHierarchy() async {
    await sb.init();
    await _createTable(decksTableName);
    await _createTable(presentationsTableName);
    await _createTable(blobsTableName);
  }
}
