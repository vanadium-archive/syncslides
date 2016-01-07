// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

part of syncbase_store;

class _AppState extends AppState {
  model.User get user => _user;
  model.Settings get settings => _settings;
  UnmodifiableMapView<String, DeckState> decks;
  UnmodifiableListView<model.PresentationAdvertisement> advertisedPresentations;
  UnmodifiableMapView<String,
      model.PresentationAdvertisement> presentationAdvertisements;

  _AppState() {
    _user = null;
    _settings = null;
    decks = new UnmodifiableMapView(_decks);
    advertisedPresentations =
        new UnmodifiableListView(_advertisedPresentations);
    presentationAdvertisements =
        new UnmodifiableMapView(_presentationsAdvertisements);
  }

  model.User _user;
  model.Settings _settings;
  Map<String, _DeckState> _decks = new Map();
  List<model.PresentationAdvertisement> _advertisedPresentations = new List();
  Map<String, model.PresentationAdvertisement> _presentationsAdvertisements =
      new Map();

  _DeckState _getOrCreateDeckState(String deckId) {
    return _decks.putIfAbsent(deckId, () {
      return new _DeckState();
    });
  }
}

class _DeckState extends DeckState {
  model.Deck _deck;
  model.Deck get deck => _deck;

  List<model.Slide> _slides = new List();
  UnmodifiableListView<model.Slide> slides;

  _PresentationState _presentation = null;
  PresentationState get presentation {
    if (_isPresenting) {
      return _presentation;
    }
    return null;
  }

  int _currSlideNum = 0;
  int get currSlideNum => _currSlideNum;

  bool _isPresenting = false;

  _DeckState() {
    slides = new UnmodifiableListView(_slides);
  }

  _PresentationState _getOrCreatePresentationState(String presentationId) {
    if (_presentation == null || _presentation.key != presentationId) {
      _presentation = new _PresentationState(presentationId);
    }
    return _presentation;
  }
}

class _PresentationState extends PresentationState {
  final String key;

  int _currSlideNum = 0;
  int get currSlideNum => _currSlideNum;

  model.User _driver;
  model.User get driver => _driver;

  bool _isOwner = false;
  bool get isOwner => _isOwner;

  bool _isFollowingPresentation = true;
  bool get isFollowingPresentation => _isFollowingPresentation;

  List<model.Question> _questions = new List();
  UnmodifiableListView<model.Question> questions;

  _PresentationState(this.key) {
    questions = new UnmodifiableListView(_questions);
  }
}
