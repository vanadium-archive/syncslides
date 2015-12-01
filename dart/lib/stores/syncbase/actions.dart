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
        sb.SyncbaseTable tb = await _getPresentationsTable();
        await tb.put(
            keyutil.getPresentationCurrSlideNumKey(
                deckId, deckState.presentation.key),
            [slideNum]);
      } else {
        // User is not driving the presentation so they are navigating on their own.
        deckState.presentation._isFollowingPresentation = false;
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
    String syncgroupName = _getPresentationSyncgroupName(_state.settings, uuid);

    model.Deck deck = _state._getOrCreateDeckState(deckId)._deck;
    var presentation =
        new model.PresentationAdvertisement(uuid, deck, syncgroupName);

    await sb.createSyncgroup(_state.settings.mounttable, syncgroupName, [
      sb.SyncbaseClient.syncgroupPrefix(decksTableName, deckId),
      sb.SyncbaseClient.syncgroupPrefix(presentationsTableName, deckId)
    ]);

    await discovery.advertise(presentation);
    _state._advertisedPresentations.add(presentation);

    // Set the presentation state for the deck.
    _DeckState deckState = _state._getOrCreateDeckState(deckId);
    _PresentationState presentationstate =
        deckState._getOrCreatePresentationState(presentation.key);
    presentationstate._isOwner = true;

    setDefaultsAndJoin() async {
      // Set the current slide number to 0.
      sb.SyncbaseTable tb = await _getPresentationsTable();
      await tb.put(
          keyutil.getPresentationCurrSlideNumKey(deckId, presentation.key),
          [0]);

      // Set the current user as the driver.
      await _setPresentationDriver(deckId, presentation.key, _state.user);

      // Also join the presentation.
      await joinPresentation(presentation);
    }

    try {
      // Wait for join. If it fails, remove the presentation state from the deck.
      await setDefaultsAndJoin();
    } catch (e) {
      deckState._presentation = null;
      throw e;
    }

    return presentation;
  }

  Future joinPresentation(model.PresentationAdvertisement presentation) async {
    String deckId = presentation.deck.key;

    // Set the presentation state for the deck.
    _DeckState deckState = _state._getOrCreateDeckState(deckId);
    deckState._getOrCreatePresentationState(presentation.key);

    // Wait until at least the current slide number, driver and the slide for current slide number is synced.
    join() async {
      bool isMyOwnPresentation =
          _state._advertisedPresentations.any((p) => p.key == presentation.key);
      if (!isMyOwnPresentation) {
        await sb.joinSyncgroup(presentation.syncgroupName);
      }

      Completer completer = new Completer();
      new Timer.periodic(new Duration(milliseconds: 30), (Timer timer) {
        if (_state._decks.containsKey(deckId) &&
            _state._decks[deckId].deck != null &&
            _state._decks[deckId].slides.length >
                _state._decks[deckId].currSlideNum &&
            _state._decks[deckId].presentation != null &&
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
      deckState._presentation = null;
      throw e;
    }

    log.info('Joined presentation ${presentation.key}');
  }

  Future stopPresentation(String presentationId) async {
    await discovery.stopAdvertising(presentationId);
    _state._advertisedPresentations.removeWhere((p) => p.key == presentationId);
    _state._decks.values.forEach((_DeckState deck) {
      if (deck.presentation != null &&
          deck.presentation.key == presentationId) {
        deck._presentation = null;
      }
    });
    log.info('Presentation $presentationId stopped');
  }

  Future stopAllPresentations() async {
    // Stop all presentations in parallel.
    return Future.wait(_state._advertisedPresentations
        .map((model.PresentationAdvertisement p) {
      return stopPresentation(p.key);
    }));
  }

  Future followPresentation(String deckId) async {
    var deckState = _state._getOrCreateDeckState(deckId);

    if (deckState.presentation == null) {
      throw new ArgumentError.value(deckId, 'Deck is not being presented.');
    }

    // Set the current slide number to the presentation's current slide number.
    await setCurrSlideNum(deckId, deckState.presentation.currSlideNum);

    deckState.presentation._isFollowingPresentation = true;
  }

  Future askQuestion(String deckId, int slideNum, String questionText) async {
    var deckState = _state._getOrCreateDeckState(deckId);

    if (deckState.presentation == null) {
      throw new ArgumentError.value(deckId,
          'Cannot ask a question because deck is not part of a presentation');
    }

    sb.SyncbaseTable tb = await _getPresentationsTable();
    String questionId = uuidutil.createUuid();

    model.Question question = new model.Question(
        questionId, questionText, slideNum, _state.user, new DateTime.now());

    var key = keyutil.getPresentationQuestionKey(
        deckId, deckState.presentation.key, questionId);

    await tb.put(key, UTF8.encode(question.toJson()));
  }

  Future setDriver(String deckId, model.User driver) async {
    var deckState = _state._getOrCreateDeckState(deckId);

    if (deckState.presentation == null) {
      throw new ArgumentError.value(deckId,
          'Cannot set the driver because deck is not part of a presentation');
    }
    await _setPresentationDriver(deckId, deckState.presentation.key, driver);
  }
}

//////////////////////////////////////
// Utilities

Future _setPresentationDriver(
    String deckId, String presentationId, model.User driver) async {
  sb.SyncbaseTable tb = await _getPresentationsTable();
  await tb.put(keyutil.getPresentationDriverKey(deckId, presentationId),
      UTF8.encode(driver.toJson()));
}

String _getPresentationSyncgroupName(
    model.Settings settings, String presentationId) {
  return '${settings.mounttable}/${settings.deviceId}/%%sync/$presentationId';
}

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
