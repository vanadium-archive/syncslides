// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../stores/store.dart';
import '../styles/common.dart' as style;
import '../utils/image_provider.dart' as imageProvider;
import 'slideshow_immersive.dart';
import 'syncslides_page.dart';

final Logger log = new Logger('components/slideshow');

class SlideshowPage extends SyncSlidesPage {
  final String _deckId;

  SlideshowPage(this._deckId);

  Widget build(BuildContext context, AppState appState, AppActions appActions) {
    if (!appState.decks.containsKey(_deckId)) {
      // TODO(aghassemi): Proper error page with navigation back to main view.
      return new Text('Deck no longer exists.');
    }

    return new Scaffold(
        body: new Material(
            child: new SlideShow(appActions, appState.decks[_deckId])));
  }
}

class SlideShow extends StatelessComponent {
  AppActions _appActions;
  DeckState _deckState;
  NavigatorState _navigator;
  int _currSlideNum;

  SlideShow(this._appActions, this._deckState);

  Widget build(BuildContext context) {
    _navigator = Navigator.of(context);

    if (_deckState.slides.length == 0) {
      // TODO(aghassemi): Proper error page with navigation back to main view.
      return new Text('No slide to show.');
    }

    if (_deckState.presentation != null &&
        _deckState.presentation.isFollowingPresentation) {
      _currSlideNum = _deckState.presentation.currSlideNum;
    } else {
      _currSlideNum = _deckState.currSlideNum;
    }

    if (_currSlideNum >= _deckState.slides.length) {
      // TODO(aghassemi): Can this ever happen?
      //  -What if slide number set by another peer is synced before the actual slides?
      //  -What if we have navigated to a particular slide on our own and peer deletes that slide?
      // I think without careful batching and consuming watch events as batches, this could happen
      // maybe for a split second until rest of data syncs up.
      // UI needs to be bullet-roof, a flicker in the UI is better than an exception and crash.
      log.shout(
          'Current slide number $_currSlideNum is greater than the number of slides ${_deckState.slides.length}.');

      // TODO(aghassemi): Proper error page with navigation back to main view.
      return new Text('Slide does not exist.');
    }

    if (MediaQuery.of(context).orientation == Orientation.landscape) {
      return _buildLandscapeLayout(context);
    } else {
      return _buildPortraitLayout(context);
    }
  }

  Widget _buildPortraitLayout(BuildContext context) {
    // Portrait mode is a column layout divided as 5 parts image, 1 part actionbar
    // 3 parts notes and 3 parts next/previous navigation thumbnails.
    var image = new Flexible(child: _buildImage(), flex: 5);
    var actions = new Flexible(child: _buildActions(), flex: 1);
    var notes = new Flexible(child: _buildNotes(), flex: 3);
    var nav = new Flexible(child: _buildPortraitNav(), flex: 3);
    var layout = new Column([image, actions, notes, nav],
        alignItems: FlexAlignItems.stretch);

    return layout;
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    // Landscape mode is a two column layout.
    // First column is divided as 5 parts notes, 8 parts parts next/previous navigation thumbnails.
    // Second column is divided as 11 parts image, 2 parts actionbar.
    var notes = new Flexible(child: _buildNotes(), flex: 5);
    var nav = new Flexible(child: _buildLandscapeNav(), flex: 8);

    var image = new Flexible(child: _buildImage(), flex: 11);
    var actions = new Flexible(child: _buildActions(), flex: 2);

    var notesAndNavColumn = new Flexible(
        child: new Column([notes, nav], alignItems: FlexAlignItems.stretch),
        flex: 4);
    var imageAndActionsColumn = new Flexible(
        child: new Column([image, actions], alignItems: FlexAlignItems.stretch),
        flex: 16);

    var layout = new Row([notesAndNavColumn, imageAndActionsColumn],
        alignItems: FlexAlignItems.stretch);

    return layout;
  }

  Widget _buildPortraitNav() {
    return new Row([
      _buildThumbnailNav(_currSlideNum - 1),
      _buildThumbnailNav(_currSlideNum + 1)
    ]);
  }

  Widget _buildLandscapeNav() {
    return new Column([
      _buildThumbnailNav(_currSlideNum - 1),
      _buildThumbnailNav(_currSlideNum + 1)
    ]);
  }

  Widget _buildImage() {
    var provider = imageProvider.getSlideImage(
        _deckState.deck.key, _deckState.slides[_currSlideNum]);

    var image = new AsyncImage(provider: provider);

    // If not driving the presentation, tapping the image navigates to the immersive mode.
    if (_deckState.presentation == null || !_deckState.presentation.isDriving) {
      image = new InkWell(child: image, onTap: () {
        _navigator.push(new MaterialPageRoute(
            builder: (context) =>
                new SlideshowImmersivePage(_deckState.deck.key)));
      });
    }

    return new Row([image],
        justifyContent: FlexJustifyContent.center,
        alignItems: FlexAlignItems.stretch);
  }

  Widget _buildNotes() {
    // TODO(aghassemi): Notes data.
    var notes =
        new Text('Notes (only you see these)', style: style.Text.subtitleStyle);
    var container = new Container(
        child: notes,
        padding: style.Spacing.normalPadding,
        decoration: new BoxDecoration(
            border: new Border(
                bottom: new BorderSide(color: style.theme.dividerColor))));
    return container;
  }

  Widget _buildThumbnailNav(int slideNum) {
    var container;

    if (slideNum >= 0 && slideNum < _deckState.slides.length) {
      var thumbnail = new AsyncImage(
          provider: imageProvider.getSlideImage(
              _deckState.deck.key, _deckState.slides[slideNum]),
          fit: ImageFit.scaleDown);

      container = new Row([thumbnail]);
      container = new InkWell(child: container, onTap: () {
        _appActions.setCurrSlideNum(_deckState.deck.key, slideNum);
      });
    } else {
      // Empty grey placeholder.
      container = new Container(
          decoration: new BoxDecoration(
              backgroundColor: style.theme.primarySwatch[100]));
    }

    return new Flexible(child: container, flex: 1);
  }

  Widget _buildActions() {
    // It collects a list of action widgets for the action bar and fabs.
    // Left contains items that are in-line on the left side of the UI.
    // Right contains the FABs that hover over the right side of the UI.
    List<Widget> left = [];
    List<Widget> right = [];

    _buildActions_prev(left, right);
    _buildActions_slidelist(left, right);
    _buildActions_next(left, right);
    _buildActions_followPresentation(left, right);

    return new ToolBar(
        left: new Row(_buildActions_addMargin(left)), right: right);
  }

  void _buildActions_prev(List<Widget> left, List<Widget> right) {
    if (_currSlideNum == 0) {
      return;
    }
    var prev =
        new InkWell(child: new Icon(icon: 'navigation/arrow_back'), onTap: () {
      _appActions.setCurrSlideNum(_deckState.deck.key, _currSlideNum - 1);
    });
    left.add(prev);
  }

  void _buildActions_slidelist(List<Widget> left, List<Widget> right) {
    var slideList =
        new InkWell(child: new Icon(icon: 'maps/layers'), onTap: () {
      _navigator.pop();
    });
    left.add(slideList);
  }

  final Matrix4 moveUpFabTransform =
      new Matrix4.identity().translate(0.0, -27.5);

  void _buildActions_next(List<Widget> left, List<Widget> right) {
    if (_currSlideNum >= (_deckState.slides.length - 1)) {
      return;
    }

    var nextOnTap = () {
      _appActions.setCurrSlideNum(_deckState.deck.key, _currSlideNum + 1);
    };

    // If driving the presentation, show a bigger FAB next button on the right side,
    // otherwise a regular next button on the left side.
    if (_deckState.presentation != null && _deckState.presentation.isDriving) {
      var next = new FloatingActionButton(
          child: new Icon(icon: 'navigation/arrow_forward'),
          onPressed: nextOnTap);

      var container =
          new Container(child: next, margin: style.Spacing.fabMargin);
      next = new Transform(transform: moveUpFabTransform, child: container);

      right.add(next);
    } else {
      var next = new InkWell(
          child: new Icon(icon: 'navigation/arrow_forward'), onTap: nextOnTap);
      left.add(next);
    }
  }

  void _buildActions_followPresentation(List<Widget> left, List<Widget> right) {
    if (_deckState.presentation == null ||
        _deckState.presentation.isFollowingPresentation) {
      return;
    }

    var syncNav = new FloatingActionButton(
        child: new Icon(icon: 'notification/sync'), onPressed: () async {
      _appActions.followPresentation(_deckState.deck.key);
    });

    syncNav =
        new Container(child: syncNav, margin: style.Spacing.actionsMargin);
    syncNav = new Transform(transform: moveUpFabTransform, child: syncNav);

    right.add(syncNav);
  }

  _buildActions_addMargin(List<Widget> actions) {
    return actions
        .map(
            (w) => new Container(child: w, margin: style.Spacing.actionsMargin))
        .toList();
  }
}
