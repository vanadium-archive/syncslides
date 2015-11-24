// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../models/all.dart' as model;
import '../stores/store.dart';
import '../styles/common.dart' as style;
import '../utils/image_provider.dart' as imageProvider;
import 'syncslides_page.dart';

final Logger log = new Logger('store/syncbase_store');

class SlideshowPage extends SyncSlidesPage {
  final String _deckId;
  final String _presentationId;

  SlideshowPage(this._deckId, {String presentationId})
      : _presentationId = presentationId;

  Widget build(BuildContext context, AppState appState, AppActions appActions) {
    if (!appState.decks.containsKey(_deckId)) {
      // TODO(aghassemi): Proper error page with navigation back to main view.
      return new Text('Deck no longer exists.');
    }

    var deckState = appState.decks[_deckId];

    return new Scaffold(
        toolBar: new ToolBar(
            left: new IconButton(
                icon: 'navigation/arrow_back',
                onPressed: () => Navigator.of(context).pop())),
        floatingActionButton:
            _buildSyncUpNavigationFab(context, appState, appActions),
        body: new Material(
            child: new SlideShow(appActions, deckState,
                appState.presentations[_presentationId])));
  }

  _buildSyncUpNavigationFab(
      BuildContext context, AppState appState, AppActions appActions) {
    if (_presentationId == null) {
      // Not in a presentation.
      return null;
    }

    PresentationState presentationState =
        appState.presentations[_presentationId];

    // If not navigating out of sync, do not show the sync icon.
    if (presentationState == null || !presentationState.isNavigationOutOfSync) {
      return null;
    }

    return new FloatingActionButton(child: new Icon(icon: 'notification/sync'),
        onPressed: () async {
      appActions.syncUpNavigationWithPresentation(_deckId, _presentationId);
    });
  }
}

class SlideShow extends StatelessComponent {
  AppActions _appActions;
  DeckState _deckState;
  PresentationState _presentationState;

  SlideShow(this._appActions, this._deckState, this._presentationState);

  Widget build(BuildContext context) {
    if (_deckState.slides.length == 0) {
      // TODO(aghassemi): Proper error page with navigation back to main view.
      return new Text('No slide to show.');
    }

    int currSlideNum;

    bool isFollowingPresenter =
        _presentationState != null && !_presentationState.isNavigationOutOfSync;

    if (isFollowingPresenter) {
      currSlideNum = _presentationState.currSlideNum;
    } else {
      currSlideNum = _deckState.currSlideNum;
    }

    if (currSlideNum >= _deckState.slides.length) {
      // TODO(aghassemi): Can this ever happen?
      //  -What if slide number set by another peer is synced before the actual slides?
      //  -What if we have navigated to a particular slide on our own and peer deletes that slide?
      // I think without careful batching and consuming watch events as batches, this could happen
      // maybe for a split second until rest of data syncs up.
      // UI needs to be bullet-roof, a flicker in the UI is better than an exception and crash.
      log.shout(
          'Current slide number $currSlideNum is greater than the number of slides ${_deckState.slides.length}');

      // TODO(aghassemi): Proper error page with navigation back to main view.
      return new Text('Slide does not exist.');
    }

    var slideData = _deckState.slides[currSlideNum];
    var image = new AsyncImage(
        provider: imageProvider.getSlideImage(_deckState.deck.key, slideData),
        fit: ImageFit.contain);
    var navWidgets = [
      _buildSlideNav(currSlideNum - 1),
      _buildSlideNav(currSlideNum + 1)
    ];

    return new Block(
        [image, new Text(currSlideNum.toString()), new Row(navWidgets)]);
  }

  Widget _buildSlideNav(int slideNum) {
    var card;

    if (slideNum >= 0 && slideNum < _deckState.slides.length) {
      var onTap = () => _appActions.setCurrSlideNum(
          _deckState.deck.key, slideNum,
          presentationId: _presentationState?.key);

      card = _buildThumbnailNav(
          _deckState.deck.key, slideNum, _deckState.slides[slideNum],
          onTap: onTap);
    } else {
      card = new Container(
          width: style.Size.thumbnailNavWidth,
          height: style.Size.thumbnailNavHeight);
    }
    // TODO(dynin): overlay 'Previous' / 'Next' text

    return new Container(child: card, margin: style.Spacing.thumbnailNavMargin);
  }
}

Widget _buildThumbnailNav(String deckId, int slideIndex, model.Slide slideData,
    {Function onTap}) {
  var thumbnail = new AsyncImage(
      provider: imageProvider.getSlideImage(deckId, slideData),
      height: style.Size.thumbnailNavHeight,
      fit: ImageFit.cover);

  return new InkWell(child: thumbnail, onTap: onTap);
}
