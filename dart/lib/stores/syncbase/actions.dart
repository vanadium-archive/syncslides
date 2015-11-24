// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

part of syncbase_store;

class _AppActions extends AppActions {
  _AppState _state;
  Function _emitChange;
  _AppActions(this._state, this._emitChange);

  //////////////////////////////////////
  // Decks

  Future addDeck(model.Deck deck) async {
    log.info("Adding deck ${deck.name}...");
    sb.SyncbaseTable tb = await _getDecksTable();
    await tb.put(deck.key, UTF8.encode(deck.toJson()));
    log.info("Deck ${deck.name} added.");
  }

  Future removeDeck(String deckKey) async {
    sb.SyncbaseTable tb = await _getDecksTable();
    tb.deleteRange(new sb.RowRange.prefix(deckKey));
  }

  Future setSlides(String deckKey, List<model.Slide> slides) async {
    sb.SyncbaseTable tb = await _getDecksTable();

    slides.forEach((slide) async {
      // TODO(aghassemi): Use batching.
      await tb.put(
          keyutil.getSlideKey(deckKey, slide.num), UTF8.encode(slide.toJson()));
    });
  }

  Future setCurrSlideNum(String deckId, int slideNum,
      {String presentationId}) async {
    var deckState = _state._getOrCreateDeckState(deckId);
    if (slideNum < 0 || slideNum >= deckState.slides.length) {
      throw new ArgumentError.value(slideNum,
          "Slide number out of range. Only ${deckState.slides.length} slides exist.");
    }

    // TODO(aghassemi): Have a session table to persist UI state such as
    // local slide number within a deck, whether user is navigating a presentation
    // on their own, and similar UI state that is desirable to be persisted.
    deckState._currSlideNum = slideNum;

    // Is slide number change happening within a presentation?
    if (presentationId != null) {
      if (!_state.presentations.containsKey(presentationId)) {
        throw new ArgumentError.value(
            presentationId, "Presentation does not exist.");
      }

      _PresentationState presentationState =
          _state.presentations[presentationId];

      // Is the current user driving the presentation?
      if (presentationState.isDriving) {
        // Update the common slide number for the presentation.
        sb.SyncbaseTable tb = await _getPresentationsTable();
        await tb.put(
            keyutil.getPresentationCurrSlideNumKey(deckId, presentationId),
            [slideNum]);
      } else {
        // User is not driving the presentation so they are navigating on their own.
        presentationState._isNavigationOutOfSync = true;
      }
    }
    _emitChange();
  }

  Future loadDemoDeck() {
    return new Loader.demo().loadDeck();
  }

  Future loadDeckFromSdCard() {
    return new Loader.demo().loadDeck();
  }

  //////////////////////////////////////
  // Presentation

  Future<model.PresentationAdvertisement> startPresentation(
      String deckId) async {
    var alreadyAdvertised = _state._advertisedPresentations
        .any((model.PresentationAdvertisement p) => p.deck.key == deckId);
    if (alreadyAdvertised) {
      throw new ArgumentError.value(deckId,
          'Cannot simultaneously present the same deck. Presentation already in progress.');
    }

    if (!_state._decks.containsKey(deckId)) {
      throw new ArgumentError.value(deckId, 'Deck no longer exists.');
    }

    String uuid = uuidutil.createUuid();
    String syncgroupName = keyutil.getPresentationSyncgroupName(uuid);

    model.Deck deck = _state._getOrCreateDeckState(deckId)._deck;
    var presentation =
        new model.PresentationAdvertisement(uuid, deck, syncgroupName);

    await sb.createSyncgroup(syncgroupName, [
      sb.SyncbaseClient.syncgroupPrefix(decksTableName, deckId),
      sb.SyncbaseClient.syncgroupPrefix(presentationsTableName, deckId)
    ]);

    await discovery.advertise(presentation);
    _state._advertisedPresentations.add(presentation);

    await joinPresentation(presentation);

    return presentation;
  }

  Future joinPresentation(model.PresentationAdvertisement presentation) async {
    bool isMyOwnPresentation =
        _state._advertisedPresentations.any((p) => p.key == presentation.key);

    if (!isMyOwnPresentation) {
      await sb.joinSyncgroup(presentation.syncgroupName);
      String deckId = presentation.deck.key;
      Completer completer = new Completer();

      // Wait until at least the slide for current page number is synced.
      new Timer.periodic(new Duration(milliseconds: 30), (Timer timer) {
        if (_state._decks.containsKey(deckId) &&
            _state._decks[deckId].deck != null &&
            _state._decks[deckId].slides.length >
                _state._decks[deckId].currSlideNum &&
            !completer.isCompleted) {
          timer.cancel();
          completer.complete();
        }
      });
      await completer.future.timeout(new Duration(seconds: 20));
    }

    _PresentationState presentationState =
        _state._getOrCreatePresentationState(presentation.key);

    // TODO(aghassemi): For now, only the presenter can drive. Later when we have
    // identity and delegation support, this will change to: if "driver == me".
    presentationState._isDriving = isMyOwnPresentation;

    log.info('Joined presentation ${presentation.key}');
  }

  Future stopPresentation(String presentationId) async {
    await discovery.stopAdvertising(presentationId);
    _state._advertisedPresentations.removeWhere((p) => p.key == presentationId);
    _state._presentations.remove(presentationId);
    log.info('Presentation $presentationId stopped');
  }

  Future stopAllPresentations() async {
    // Stop all presentations in parallel.
    return Future.wait(_state._advertisedPresentations
        .map((model.PresentationAdvertisement p) {
      return stopPresentation(p.key);
    }));
  }

  Future syncUpNavigationWithPresentation(
      String deckId, String presentationId) async {
    if (!_state.presentations.containsKey(presentationId)) {
      throw new ArgumentError.value(
          presentationId, "Presentation does not exist.");
    }

    _PresentationState presentationState = _state.presentations[presentationId];

    // Set the current slide number to the presentation's current slide number.
    await setCurrSlideNum(deckId, presentationState.currSlideNum);

    presentationState._isNavigationOutOfSync = false;
  }
}

//////////////////////////////////////
// Utilities

Future<sb.SyncbaseTable> _getTable(String tableName) async {
  sb.SyncbaseDatabase sbDb = await sb.getDatabase();
  sb.SyncbaseTable tb = sbDb.table(tableName);
  try {
    await tb.create(sb.createOpenPerms());
  } catch (e) {
    if (!errorsutil.isExistsError(e)) {
      throw e;
    }
  }
  return tb;
}

Future<sb.SyncbaseTable> _getDecksTable() {
  return _getTable(decksTableName);
}

Future<sb.SyncbaseTable> _getPresentationsTable() {
  return _getTable(presentationsTableName);
}
