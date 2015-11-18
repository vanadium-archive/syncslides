// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import '../models/all.dart' as model;

import 'state.dart';
import 'store_factory.dart' as storeFactory;

// Provides APIs for reading and writing app-related data.
abstract class Store {
  static Store _singletonStore = storeFactory.create();

  factory Store.singleton() {
    return _singletonStore;
  }

  //////////////////////////////////////
  // State

  State get state;
  Stream get onStateChange;

  //////////////////////////////////////
  // Decks

  // Returns all the existing decks.
  Future<List<model.Deck>> getAllDecks();

  // Returns the deck for the given key.
  Future<model.Deck> getDeck(String key);

  // Adds a new deck.
  Future addDeck(model.Deck deck);

  // Removes a deck given its key.
  Future removeDeck(String key);

  // Event that fires when deck are added or removed.
  // The up-to-date list of decks with be sent to listeners.
  Stream<List<model.Deck>> get onDecksChange;

  //////////////////////////////////////
  // Slides

  // Returns the list of all slides for a deck.
  Future<List<model.Slide>> getAllSlides(String deckKey);

  // Sets the slides for a deck.
  Future setSlides(String deckKey, List<model.Slide> slides);

  //////////////////////////////////////
  // Slideshow

  Future<int> getCurrSlideNum(String deckId);

  Future setCurrSlideNum(String deckId, int slideNum);

  Stream<int> onCurrSlideNumChange(String deckId);

  //////////////////////////////////////
  // Presentation

  Future<model.PresentationAdvertisement> startPresentation(String deckId);

  Future stopPresentation(String presentationId);

  Future stopAllPresentations();
}
