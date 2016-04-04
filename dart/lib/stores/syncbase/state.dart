// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

part of syncbase_store;

class _AppState extends AppState {
  _AppState() {
    _user = null;
    _settings = null;
    decks = new UnmodifiableMapView(_decks);
    presentationAdvertisements =
        new UnmodifiableMapView(_presentationsAdvertisements);
  }

  @override
  model.User get user => _user;
  @override
  model.Settings get settings => _settings;

  @override
  UnmodifiableMapView<String, DeckState> decks;

  @override
  model.PresentationAdvertisement get advertisedPresentation =>
      _advertisedPresentation;

  @override
  UnmodifiableMapView<String, model.PresentationAdvertisement>
      presentationAdvertisements;

  model.User _user;
  model.Settings _settings;
  Map<String, _DeckState> _decks = new Map();
  model.PresentationAdvertisement _advertisedPresentation;
  Map<String, model.PresentationAdvertisement> _presentationsAdvertisements =
      new Map();

  _DeckState _getOrCreateDeckState(String deckId) {
    return _decks.putIfAbsent(deckId, () {
      return new _DeckState();
    });
  }
}

class _DeckState extends DeckState {
  _DeckState() {
    slides = new UnmodifiableListView(_slides);
  }

  model.Deck _deck;
  @override
  model.Deck get deck => _deck;

  List<model.Slide> _slides = new List();
  @override
  UnmodifiableListView<model.Slide> slides;

  _PresentationState _presentation;
  @override
  PresentationState get presentation {
    if (_isPresenting) {
      return _presentation;
    }
    return null;
  }

  int _currSlideNum = 0;
  @override
  int get currSlideNum => _currSlideNum;

  bool _isPresenting = false;

  _PresentationState _getOrCreatePresentationState(String presentationId) {
    if (_presentation == null || _presentation.key != presentationId) {
      _presentation = new _PresentationState(presentationId);
    }
    return _presentation;
  }
}

class _PresentationState extends PresentationState {
  _PresentationState(this.key) {
    questions = new UnmodifiableListView(_questions);
  }

  @override
  final String key;

  int _currSlideNum = 0;
  @override
  int get currSlideNum => _currSlideNum;

  model.User _driver;
  @override
  model.User get driver => _driver;

  bool _isOwner = false;
  @override
  bool get isOwner => _isOwner;

  bool _isFollowingPresentation = true;
  @override
  bool get isFollowingPresentation => _isFollowingPresentation;

  List<model.Question> _questions = new List();
  @override
  UnmodifiableListView<model.Question> questions;
}
