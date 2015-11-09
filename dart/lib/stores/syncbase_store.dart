// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import '../models/all.dart' as model;
import '../syncbase/client.dart' as sb;

import 'keyutil.dart' as keyutil;
import 'store.dart';

const String decksTableName = 'Decks';

// Implementation of  using Syncbase (http://v.io/syncbase) storage system.
class SyncbaseStore implements Store {
  StreamController _onDecksChangeController;
  SyncbaseStore() {
    _onDecksChangeController = new StreamController.broadcast();
    _onDecksChangeController.onListen = () {
      sb.getDatabase().then(_startDecksWatch);
    };
  }

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

  Stream<List<model.Deck>> get onDecksChange => _onDecksChangeController.stream;

  Future<List<model.Slide>> getAllSlides(String deckKey) async {
    // Key schema is:
    // <deckId> --> Deck
    // <deckId>/slides/1 --> Slide
    // So we scan for keys that start with $deckKey/
    // Ideally this would have been a query based on Type but that is not supported yet.
    sb.SyncbaseNoSqlDatabase sbDb = await sb.getDatabase();
    String prefix = keyutil.getDeckKeyPrefix(deckKey);
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

  Future<sb.SyncbaseTable> _getDecksTable() async {
    sb.SyncbaseNoSqlDatabase sbDb = await sb.getDatabase();
    sb.SyncbaseTable tb = sbDb.table(decksTableName);
    if (await tb.exists()) {
      return tb;
    }
    await tb.create(sb.createOpenPermissions());
    return tb;
  }

  Future _startDecksWatch(sb.SyncbaseNoSqlDatabase sbDb) async {
    var resumeMarker = await sbDb.getResumeMarker();
    var stream = sbDb.watch(decksTableName, '', resumeMarker);

    var streamListener = stream.listen((sb.WatchChange change) async {
      if (keyutil.isDeckKey(change.rowKey)) {
        // TODO(aghassemi): Maybe manipulate an in-memory list based on watch
        // changes instead of getting the decks again from Syncbase.
        var decks = await getAllDecks();
        _onDecksChangeController.add(decks);
      }
    });

    // TODO(aghassemi): Currently we can not cancel a watch, only pause it.
    // Since watch stream supports blocking flow control, it is not a big deal
    // but ideally we can fully cancel a watch instead of enduing up with many
    // paused watches.
    // Also this issue becomes irrelevant if we do the TODO above regarding
    // keeping and manipulating an in-memory list based on watch.
    // https://github.com/vanadium/issues/issues/833
    _onDecksChangeController.onCancel = () => streamListener.pause();
  }

  model.Deck _toDeck(List<List<int>> row) {
    // TODO(aghassemi): Keys return from queries seems to have double quotes
    // around them.
    // See https://github.com/vanadium/issues/issues/860
    var key = UTF8.decode(row[0]).replaceAll('"', '');
    var value = UTF8.decode(row[1]);
    return new model.Deck.fromJson(key, value);
  }

  model.Slide _toSlide(List<List<int>> row) {
    var value = UTF8.decode(row[1]);
    return new model.Slide.fromJson(value);
  }
}
