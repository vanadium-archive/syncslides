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

  @override
  Future addDeck(model.Deck deck) async {
    log.info("Adding deck ${deck.name}...");
    sb.SyncbaseTable tb = _getDecksTable();
    await tb.put(deck.key, UTF8.encode(deck.toJson()));
    log.info("Deck ${deck.name} added.");
  }

  @override
  Future removeDeck(String deckKey) async {
    sb.SyncbaseTable tb = _getDecksTable();
    tb.deleteRange(new sb.RowRange.prefix(deckKey));
  }

  @override
  Future setSlides(String deckKey, List<model.Slide> slides) async {
    sb.SyncbaseTable tb = _getDecksTable();

    slides.forEach((slide) async {
      // TODO(aghassemi): Use batching.
      await tb.put(
          keyutil.getSlideKey(deckKey, slide.num), UTF8.encode(slide.toJson()));
    });
  }

  @override
  Future setCurrSlideNum(String deckId, int slideNum) async {
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
    if (deckState.presentation != null) {
      // Is the current user driving the presentation?
      if (deckState.presentation.isDriving(_state.user)) {
        // Update the common slide number for the presentation.
        sb.SyncbaseTable tb = _getPresentationsTable();
        await tb.put(
            keyutil.getPresentationCurrSlideNumKey(
                deckId, deckState.presentation.key),
            UTF8.encode(slideNum.toString()));
      } else {
        // User is not driving the presentation so they are navigating on their own.
        deckState.presentation._isFollowingPresentation = false;
      }
    }
    _emitChange();
  }

  @override
  Future loadDeckFromSdCard() {
    return new Loader.singleton().loadDeck();
  }

  //////////////////////////////////////
  // Presentation

  @override
  Future<model.PresentationAdvertisement> startPresentation(
      String deckId) async {
    if (!_state._decks.containsKey(deckId)) {
      throw new ArgumentError.value(deckId, 'Deck no longer exists.');
    }

    // Stop the existing presentation, if any.
    if (_state._advertisedPresentation != null) {
      await stopPresentation(_state._advertisedPresentation.key);
    }

    model.Deck deck = _state._getOrCreateDeckState(deckId)._deck;
    String presentationId = uuidutil.createUuid();
    String syncgroupName = _getSyncgroupName(_state.settings, presentationId);
    String thumbnailSyncgroupName =
        _getSyncgroupName(_state.settings, deck.thumbnail.key);

    var presentation = new model.PresentationAdvertisement(
        presentationId, deck, syncgroupName, thumbnailSyncgroupName);

    // Syncgroup for deck and presentation data, including blobs.
    await sb.createSyncgroup(_state.settings.mounttable, syncgroupName, [
      sb.SyncbaseClient.syncgroupPrefix(decksTableName, deckId),
      sb.SyncbaseClient.syncgroupPrefix(presentationsTableName,
          keyutil.getPresentationPrefix(deckId, presentationId)),
      sb.SyncbaseClient.syncgroupPrefix(blobsTableName, deckId)
    ]);

    // TODO(aghassemi): Use a simple RPC instead of a syncgroup to get the thumbnail.
    // See https://github.com/vanadium/syncslides/issues/17
    // Syncgroup for deck thumbnail.
    await sb.createSyncgroup(
        _state.settings.mounttable, thumbnailSyncgroupName, [
      sb.SyncbaseClient.syncgroupPrefix(blobsTableName, deck.thumbnail.key)
    ]);

    await discovery.advertise(presentation);
    _state._advertisedPresentation = presentation;

    // Set the presentation state for the deck.
    _DeckState deckState = _state._getOrCreateDeckState(deckId);
    _PresentationState presentationstate =
        deckState._getOrCreatePresentationState(presentation.key);
    presentationstate._isOwner = true;

    Future setDefaultsAndJoin() async {
      // Set the current slide number to 0.
      sb.SyncbaseTable tb = _getPresentationsTable();
      await tb.put(
          keyutil.getPresentationCurrSlideNumKey(deckId, presentation.key),
          UTF8.encode('0'));

      // Set the current user as the driver.
      await _setPresentationDriver(deckId, presentation.key, _state.user);

      // Also join the presentation.
      await joinPresentation(presentation);
    }

    try {
      // Wait for join. If it fails, remove the presentation state from the deck.
      await setDefaultsAndJoin();
    } catch (e) {
      deckState._isPresenting = false;
      throw e;
    }

    return presentation;
  }

  @override
  Future joinPresentation(model.PresentationAdvertisement presentation) async {
    String deckId = presentation.deck.key;

    // Set the presentation state for the deck.
    _DeckState deckState = _state._getOrCreateDeckState(deckId);
    deckState._getOrCreatePresentationState(presentation.key);

    deckState._isPresenting = true;

    // Wait until at least the current slide number, driver and the slide for current slide number is synced.
    Future join() async {
      bool isMyOwnPresentation =
          _state._advertisedPresentation?.key == presentation.key;
      if (!isMyOwnPresentation) {
        await sb.joinSyncgroup(presentation.syncgroupName);
      }

      Completer completer = new Completer();
      new Timer.periodic(new Duration(milliseconds: 30), (Timer timer) {
        if (_state._decks.containsKey(deckId) &&
            _state._decks[deckId].deck != null &&
            _state._decks[deckId].presentation != null &&
            _state._decks[deckId].slides.length >
                _state._decks[deckId].presentation.currSlideNum &&
            _state._decks[deckId].presentation.driver != null &&
            !completer.isCompleted) {
          timer.cancel();
          completer.complete();
        }
      });
      await completer.future.timeout(new Duration(seconds: 20));
    }

    try {
      // Wait for join. If it fails, remove the presentation state from the deck.
      await join();
    } catch (e) {
      deckState._isPresenting = false;
      throw e;
    }

    log.info('Joined presentation ${presentation.key}');
  }

  @override
  Future stopPresentation(String presentationId) async {
    await discovery.stopAdvertising(presentationId);
    _state._advertisedPresentation = null;
    _state._decks.values.forEach((_DeckState deck) {
      if (deck.presentation != null &&
          deck.presentation.key == presentationId) {
        deck._isPresenting = false;
      }
    });
    _emitChange();
    log.info('Presentation $presentationId stopped');
  }

  @override
  Future followPresentation(String deckId) async {
    var deckState = _state._getOrCreateDeckState(deckId);

    if (deckState.presentation == null) {
      throw new ArgumentError.value(deckId, 'Deck is not being presented.');
    }

    // Set the current slide number to the presentation's current slide number.
    await setCurrSlideNum(deckId, deckState.presentation.currSlideNum);

    deckState.presentation._isFollowingPresentation = true;
  }

  @override
  Future askQuestion(String deckId, int slideNum, String questionText) async {
    var deckState = _state._getOrCreateDeckState(deckId);

    if (deckState.presentation == null) {
      throw new ArgumentError.value(deckId,
          'Cannot ask a question because deck is not part of a presentation');
    }

    sb.SyncbaseTable tb = _getPresentationsTable();
    String questionId = uuidutil.createUuid();

    model.Question question = new model.Question(
        questionId, questionText, slideNum, _state.user, new DateTime.now());

    var key = keyutil.getPresentationQuestionKey(
        deckId, deckState.presentation.key, questionId);

    await tb.put(key, UTF8.encode(question.toJson()));
  }

  @override
  Future setDriver(String deckId, model.User driver) async {
    var deckState = _state._getOrCreateDeckState(deckId);

    if (deckState.presentation == null) {
      throw new ArgumentError.value(deckId,
          'Cannot set the driver because deck is not part of a presentation');
    }
    await _setPresentationDriver(deckId, deckState.presentation.key, driver);
  }

  //////////////////////////////////////
  // Blobs

  @override
  Future putBlob(String key, List<int> bytes) async {
    sb.SyncbaseTable tb = _getBlobsTable();
    await tb.put(key, bytes);
  }

  @override
  Future<List<int>> getBlob(String key) async {
    sb.SyncbaseTable tb = _getBlobsTable();
    return tb.get(key);
  }
}

//////////////////////////////////////
// Utilities

Future _setPresentationDriver(
    String deckId, String presentationId, model.User driver) async {
  sb.SyncbaseTable tb = _getPresentationsTable();
  await tb.put(keyutil.getPresentationDriverKey(deckId, presentationId),
      UTF8.encode(driver.toJson()));
}

String _getSyncgroupName(model.Settings settings, String uuid) {
  return '${settings.mounttable}/${settings.deviceId}/%%sync/$uuid';
}

sb.SyncbaseTable _getDecksTable() {
  return sb.database.table(decksTableName);
}

sb.SyncbaseTable _getPresentationsTable() {
  return sb.database.table(presentationsTableName);
}

sb.SyncbaseTable _getBlobsTable() {
  return sb.database.table(blobsTableName);
}
