// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

part of store;

// Defines all possible actions that the application can perform.
abstract class AppActions {
  //////////////////////////////////////
  // Decks

  // Adds a new deck.
  Future addDeck(model.Deck deck);

  // Removes a deck given its key.
  Future removeDeck(String key);

  // Loads a demo deck.
  Future loadDemoDeck();

  // Loads a deck from SdCard.
  Future loadDeckFromSdCard();

  // Sets the slides for a deck.
  Future setSlides(String deckKey, List<model.Slide> slides);

  // Sets the current slide number for a deck.
  Future setCurrSlideNum(String deckId, int slideNum, {String presentationId});

  //////////////////////////////////////
  // Presentation

  // Joins an advertised presentation.
  Future joinPresentation(model.PresentationAdvertisement presentation);

  // Starts a presentation.
  Future<model.PresentationAdvertisement> startPresentation(String deckId);

  // Stops the given presentation.
  Future stopPresentation(String presentationId);

  // Stops all presentations.
  Future stopAllPresentations();

  // If viewer has started navigating on their own, this will sync the navigation
  // back up with the presentation.
  Future syncUpNavigationWithPresentation(String deckId, String presentationId);
}
