// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

part of store;

// Represents the current state of the data that the application holds.
// Application is rendered purely based on this state.
// State is deeply-immutable outside of store code.
abstract class AppState {
  UnmodifiableMapView<String, DeckState> get decks;
  UnmodifiableMapView<String, PresentationState> get presentations;
  UnmodifiableListView<
      model.PresentationAdvertisement> get advertisedPresentations;
  UnmodifiableMapView<String,
      model.PresentationAdvertisement> get presentationAdvertisements;
}

abstract class DeckState {
  model.Deck get deck;
  UnmodifiableListView<model.Slide> get slides;
  int get currSlideNum;
}

abstract class PresentationState {
  String get key;
  int get currSlideNum;
  bool get isDriving;
  bool get isNavigationOutOfSync;
}
