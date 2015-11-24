// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

part of syncbase_store;

class _AppState implements AppState {
  List<model.PresentationAdvertisement> advertisedPresentations;
  Map<String, model.PresentationAdvertisement> presentationAdvertisements;
  Map<String, DeckState> decks;
  Map<String, PresentationState> presentations;

  _AppState() {
    presentationAdvertisements =
        new UnmodifiableMapView(_presentationsAdvertisements);
    decks = new UnmodifiableMapView(_decks);
    presentations = new UnmodifiableMapView(_presentations);
    advertisedPresentations =
        new UnmodifiableListView(_advertisedPresentations);
  }

  Map<String, model.PresentationAdvertisement> _presentationsAdvertisements =
      new Map();
  Map<String, _DeckState> _decks = new Map();
  Map<String, _PresentationState> _presentations = new Map();
  List<model.PresentationAdvertisement> _advertisedPresentations = new List();

  _DeckState _getOrCreateDeckState(String deckId) {
    return _decks.putIfAbsent(deckId, () {
      return new _DeckState();
    });
  }

  _PresentationState _getOrCreatePresentationState(String presentationId) {
    return _presentations.putIfAbsent(presentationId, () {
      return new _PresentationState(presentationId);
    });
  }
}

class _DeckState implements DeckState {
  model.Deck _deck;
  model.Deck get deck => _deck;

  List<model.Slide> _slides = new List();
  List<model.Slide> slides;

  int _currSlideNum = 0;
  int get currSlideNum => _currSlideNum;

  _DeckState() {
    slides = new UnmodifiableListView(_slides);
  }
}

class _PresentationState implements PresentationState {
  final String key;

  int _currSlideNum = 0;
  int get currSlideNum => _currSlideNum;

  bool _isDriving = false;
  bool get isDriving => _isDriving;

  bool _isNavigationOutOfSync = false;
  bool get isNavigationOutOfSync => _isNavigationOutOfSync;

  _PresentationState(this.key);
}
