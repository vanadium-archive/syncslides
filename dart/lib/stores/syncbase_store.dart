// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import '../models/all.dart' as model;
import '../syncbase/client.dart' as sb;
import '../utils/errors.dart' as errorsutil;

import 'keyutil.dart' as keyutil;
import 'store.dart';

const String decksTableName = 'Decks';

// Implementation of  using Syncbase (http://v.io/syncbase) storage system.
class SyncbaseStore implements Store {
  StreamController _deckChangeEmitter;
  Map<String, StreamController> _currSlideNumChangeEmitterMap;

  SyncbaseStore() {
    _deckChangeEmitter = new StreamController.broadcast();
    _currSlideNumChangeEmitterMap = new Map();
    sb.getDatabase().then((db) {
      _startDecksWatch(db);
      _startSync(db);
    });
  }

  //////////////////////////////////////
  /// Decks

  Future<List<model.Deck>> getAllDecks() async {
    // Key schema is:
    // <deckId> --> Deck
    // <deckId>/slides/1 --> Slide
    // So we scan for keys that don't have /
    // Ideally this would become a query based on Type when there is VOM/VDL
    // support in Dart and we store typed objects instead of JSON bytes.
    sb.SyncbaseNoSqlDatabase sbDb = await sb.getDatabase();
    String query = 'SELECT k, v FROM $decksTableName WHERE k NOT LIKE "%/%"';
    Stream<sb.Result> results = sbDb.exec(query);
    // NOTE(aghassemi): First row is always the name of the columns, so we skip(1).
    return results.skip(1).map((result) => _toDeck(result.values)).toList();
  }

  Future addDeck(model.Deck deck) async {
    sb.SyncbaseTable tb = await _getDecksTable();
    tb.put(deck.key, UTF8.encode(deck.toJson()));
  }

  Future removeDeck(String deckKey) async {
    sb.SyncbaseTable tb = await _getDecksTable();
    // Delete deck and all of its slides.
    tb.deleteRange(new sb.RowRange.prefix(deckKey));
  }

  Stream<List<model.Deck>> get onDecksChange => _deckChangeEmitter.stream;

  model.Deck _toDeck(List<List<int>> row) {
    // TODO(aghassemi): Keys return from queries seems to have double quotes
    // around them.
    // See https://github.com/vanadium/issues/issues/860
    var key = UTF8.decode(row[0]).replaceAll('"', '');
    var value = UTF8.decode(row[1]);
    return new model.Deck.fromJson(key, value);
  }

  //////////////////////////////////////
  /// Slides

  Future<List<model.Slide>> getAllSlides(String deckKey) async {
    // Key schema is:
    // <deckId> --> Deck
    // <deckId>/slides/1 --> Slide
    // So we scan for keys that start with $deckKey/
    // Ideally this would have been a query based on Type but that is not supported yet.
    sb.SyncbaseNoSqlDatabase sbDb = await sb.getDatabase();
    String prefix = keyutil.getSlidesKeyPrefix(deckKey);
    String query = 'SELECT k, v FROM $decksTableName WHERE k LIKE "$prefix%"';
    Stream results = sbDb.exec(query);
    return results.skip(1).map((result) => _toSlide(result.values)).toList();
  }

  Future setSlides(String deckKey, List<model.Slide> slides) async {
    sb.SyncbaseTable tb = await _getDecksTable();

    for (var i = 0; i < slides.length; i++) {
      var slide = slides[i];
      // TODO(aghassemi): Use batching when support is added.
      await tb.put(
          keyutil.getSlideKey(deckKey, i), UTF8.encode(slide.toJson()));
    }
  }

  model.Slide _toSlide(List<List<int>> row) {
    var value = UTF8.decode(row[1]);
    return new model.Slide.fromJson(value);
  }

  //////////////////////////////////////
  // Slideshow

  Future<int> getCurrSlideNum(String deckId) async {
    sb.SyncbaseTable tb = await _getDecksTable();
    var v = await tb.get(keyutil.getCurrSlideNumKey(deckId));
    if (v == null || v.isEmpty) {
      return 0;
    }
    return v[0];
  }

  Future setCurrSlideNum(String deckId, int slideNum) async {
    sb.SyncbaseTable tb = await _getDecksTable();
    var slides = await getAllSlides(deckId);
    if (slideNum >= 0 && slideNum < slides.length) {
      // TODO(aghassemi): Move outside of decks table and into a schema just for
      // storing UI state.
      await tb.put(keyutil.getCurrSlideNumKey(deckId), [slideNum]);
    }
  }

  Stream<int> onCurrSlideNumChange(String deckId) {
    return _getCurrSlideNumChangeEmitter(deckId).stream;
  }

  StreamController _getCurrSlideNumChangeEmitter(String deckId) {
    _currSlideNumChangeEmitterMap.putIfAbsent(
        deckId, () => new StreamController.broadcast());
    return _currSlideNumChangeEmitterMap[deckId];
  }

  Future<sb.SyncbaseTable> _getDecksTable() async {
    sb.SyncbaseNoSqlDatabase sbDb = await sb.getDatabase();
    sb.SyncbaseTable tb = sbDb.table(decksTableName);
    try {
      await tb.create(sb.createOpenPerms());
    } catch (e) {
      if (!errorsutil.isExistsError(e)) {
        throw e;
      }
    }
    return tb;
  }

  Future _startDecksWatch(sb.SyncbaseNoSqlDatabase sbDb) async {
    var resumeMarker = await sbDb.getResumeMarker();
    var stream = sbDb.watch(decksTableName, '', resumeMarker);

    stream.listen((sb.WatchChange change) async {
      if (keyutil.isDeckKey(change.rowKey)) {
        // TODO(aghassemi): Maybe manipulate an in-memory list based on watch
        // changes instead of getting the decks again from Syncbase.
        if (!_deckChangeEmitter.isPaused || !_deckChangeEmitter.isClosed) {
          var decks = await getAllDecks();
          _deckChangeEmitter.add(decks);
        }
      } else if (keyutil.isCurrSlideNumKey(change.rowKey)) {
        var deckId = keyutil.currSlideNumKeyToDeckId(change.rowKey);
        var emitter = _getCurrSlideNumChangeEmitter(deckId);
        if (!emitter.isPaused || !emitter.isClosed) {
          if (change.changeType == sb.WatchChangeTypes.put) {
            int currSlideNum = change.valueBytes[0];
            emitter.add(currSlideNum);
          } else {
            emitter.add(0);
          }
        }
      }
    });
  }

  Future _startSync(sb.SyncbaseNoSqlDatabase sbDb) async {}
}
