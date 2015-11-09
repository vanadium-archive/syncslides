// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import '../models/all.dart' as model;

import 'keyutil.dart' as keyutil;
import 'store.dart';

// A memory-based implementation of Store.
class MemoryStore implements Store {
  StreamController _onDecksChangeController;
  Map<String, String> _decksMap;
  Map<String, String> _slidesMap;

  MemoryStore()
      : _onDecksChangeController = new StreamController.broadcast(),
        _decksMap = new Map(),
        _slidesMap = new Map();

  Future<List<model.Deck>> getAllDecks() async {
    var decks = [];
    _decksMap.forEach((String key, String value) {
      decks.add(new model.Deck.fromJson(key, value));
    });

    return decks;
  }

  Future addDeck(model.Deck deck) async {
    var json = deck.toJson();
    _decksMap[deck.key] = json;
    getAllDecks().then(_triggerDecksChangeEvent);
  }

  Future removeDeck(String deckKey) async {
    _decksMap.remove(deckKey);
    _slidesMap.keys
        .where((slideKey) =>
            slideKey.startsWith(keyutil.getDeckKeyPrefix(deckKey)))
        .toList()
        .forEach(_slidesMap.remove);
    getAllDecks().then(_triggerDecksChangeEvent);
  }

  Stream<List<model.Deck>> get onDecksChange => _onDecksChangeController.stream;

  Future<List<model.Slide>> getAllSlides(String deckKey) async {
    var slides = [];
    _slidesMap.keys
        .where((slideKey) =>
            slideKey.startsWith(keyutil.getDeckKeyPrefix(deckKey)))
        .forEach((String key) {
      slides.add(new model.Slide.fromJson(_slidesMap[key]));
    });
    return slides;
  }

  Future setSlides(String deckKey, List<model.Slide> slides) async {
    List<String> jsonSlides = slides.map((slide) => slide.toJson()).toList();
    for (int i = 0; i < jsonSlides.length; i++) {
      _slidesMap[keyutil.getSlideKey(deckKey, i)] = jsonSlides[i];
    }
  }

  _triggerDecksChangeEvent(List<model.Deck> decks) {
    _onDecksChangeController.add(decks);
  }
}
