// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

part of store;

// Represents the current state of the data that the application holds.
// Application is rendered purely based on this state.
// State is deeply-immutable outside of store code.
abstract class AppState {
  // Current user.
  model.User get user;

  // Current settings of the app.
  model.Settings get settings;

  // List of decks.
  UnmodifiableMapView<String, DeckState> get decks;

  // List of presentations advertised by this instance of the app.
  UnmodifiableListView<
      model.PresentationAdvertisement> get advertisedPresentations;

  // List of presentations advertised by others.
  UnmodifiableMapView<String,
      model.PresentationAdvertisement> get presentationAdvertisements;
}

abstract class DeckState {
  // The deck.
  model.Deck get deck;

  // List of slides.
  UnmodifiableListView<model.Slide> get slides;

  // State of the presentation for a deck.
  // null if deck is not in a presentation.
  PresentationState get presentation;

  // Local current slide number for the deck.
  int get currSlideNum;
}

abstract class PresentationState {
  // Presentation id.
  String get key;

  // Shared slide number for the presentation.
  int get currSlideNum;

  // User who is driving the presentation.
  model.User get driver;

  // Whether current user owns the presentation.
  bool get isOwner;

  // Whether current user is following the presentation or has started
  // navigating on their own.
  bool get isFollowingPresentation;

  // Questions asked in the presentation.
  UnmodifiableListView<model.Question> get questions;

  // Returns true if the given user is driving the presentation.
  bool isDriving(model.User currUser) {
    // TODO(aghassemi): We currently check the deviceId in addition to the blessing
    // to decide if current user is the driver.
    // This can change in the future when we have the concept of user sessions and sync
    // all of a user's data across their own devices, but currently, same user using a different
    // device is treated like another user everywhere else in the UI so there is no point in
    // deviating from that behaviour for driving a presentation.
    return this.driver != null &&
        this.driver.blessing == currUser.blessing &&
        this.driver.deviceId == currUser.deviceId;
  }
}
