// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library syncbase_store;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:logging/logging.dart';

import '../../discovery/client.dart' as discovery;
import '../../loaders/loader.dart';
import '../../models/all.dart' as model;
import '../../syncbase/client.dart' as sb;
import '../../utils/errors.dart' as errorsutil;
import '../../utils/uuid.dart' as uuidutil;
import '../store.dart';
import '../utils/key.dart' as keyutil;

part 'actions.dart';
part 'state.dart';
part 'consts.dart';

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

    sb.getDatabase().then((sb.SyncbaseDatabase db) async {
      // Make sure all table exists.
      await _ensureTablesExist();

      // TODO(aghassemi): Use the multi-table scan and watch API when ready.
      // See https://github.com/vanadium/issues/issues/923
      for (String table in [decksTableName, presentationsTableName]) {
        _getInitialValuesAndStartWatching(db, table);
      }
      _startScanningForPresentations();
    });
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
    discovery.onFound.listen((model.PresentationAdvertisement newP) {
      _state._presentationsAdvertisements[newP.key] = newP;
      _triggerStateChange();
    });

    discovery.onLost.listen((String pId) {
      _state._presentationsAdvertisements.remove(pId);
      _triggerStateChange();
    });

    discovery.startScan();
  }

  Future _getInitialValuesAndStartWatching(
      sb.SyncbaseDatabase sbDb, String table) async {
    // TODO(aghassemi): Ideally we wouldn't need an initial query and can configure
    // watch to give both initial values and future changes.
    // See https://github.com/vanadium/issues/issues/917
    var batchDb =
        await sbDb.beginBatch(sb.SyncbaseClient.batchOptions(readOnly: true));
    var resumeMarker = await batchDb.getResumeMarker();

    // Get initial values in a batch.
    String query = 'SELECT k, v FROM $table';
    Stream<sb.Result> results = batchDb.exec(query);
    // NOTE(aghassemi): First row is always the name of the columns, so we skip(1).
    results.skip(1).forEach((sb.Result result) => _onChange(
        table,
        sb.WatchChangeTypes.put,
        UTF8.decode(result.values[0]),
        result.values[1]));

    await batchDb.abort();

    // Start watching from batch's resume marker.
    var stream = sbDb.watch(table, '', resumeMarker);
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
      _state.decks.remove(deckId);
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
    var presentationId =
        keyutil.presentationCurrSlideNumKeyToPresentationId(rowKey);
    var presentationState =
        _state._getOrCreatePresentationState(presentationId);
    if (changeType == sb.WatchChangeTypes.put) {
      int currSlideNum = value[0];
      presentationState._currSlideNum = currSlideNum;
    } else {
      presentationState._currSlideNum = 0;
    }
  }

  Future _ensureTablesExist() async {
    await _getDecksTable();
    await _getPresentationsTable();
  }
}
