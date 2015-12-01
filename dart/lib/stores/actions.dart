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
  Future setCurrSlideNum(String deckId, int slideNum);

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

  // If viewer has started navigating on their own, this will align the navigation
  // back up with the presentation.
  Future followPresentation(String deckId);

  // Adds a question to a specific slide within a presentation.
  Future askQuestion(String deckId, int slideNum, String questionText);

  // Sets the driver of a presentation to the given user.
  Future setDriver(String deckId, model.User driver);

  //////////////////////////////////////
  // Blobs

  // Stores the given blob bytes under the given key.
  Future putBlob(String key, List<int> bytes);

  // Gets the blob bytes for the given key.
  Future<List<int>> getBlob(String key);
}
