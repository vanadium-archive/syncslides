// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import '../models/all.dart' as model;

import 'keyutil.dart' as keyutil;
import 'store.dart';

// A memory-based implementation of Store.
class MemoryStore implements Store {
  StreamController _onDecksChangeEmitter;
  Map<String, String> _decksMap;
  Map<String, String> _slidesMap;
  Map<String, int> _currSlideNumMap;
  Map<String, StreamController> _currSlideNumChangeEmitterMap;

  MemoryStore()
      : _onDecksChangeEmitter = new StreamController.broadcast(),
        _decksMap = new Map(),
        _slidesMap = new Map(),
        _currSlideNumMap = new Map(),
        _currSlideNumChangeEmitterMap = new Map();

  //////////////////////////////////////
  /// Decks

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
    getAllDecks().then(_onDecksChangeEmitter.add);
  }

  Future removeDeck(String deckKey) async {
    _decksMap.remove(deckKey);
    _slidesMap.keys
        .where((slideKey) =>
            slideKey.startsWith(keyutil.getDeckKeyPrefix(deckKey)))
        .toList()
        .forEach(_slidesMap.remove);
    getAllDecks().then(_onDecksChangeEmitter.add);
  }

  Stream<List<model.Deck>> get onDecksChange => _onDecksChangeEmitter.stream;

  //////////////////////////////////////
  /// Slides

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

  //////////////////////////////////////
  // Slideshow

  Future<int> getCurrSlideNum(String deckId) async {
    return _currSlideNumMap[deckId] ?? 0;
  }

  Future setCurrSlideNum(String deckId, int slideNum) async {
    var slides = await getAllSlides(deckId);
    if (slideNum >= 0 && slideNum < slides.length) {
      _currSlideNumMap[deckId] = slideNum;
      _getCurrSlideNumChangeEmitter(deckId).add(slideNum);
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
}
