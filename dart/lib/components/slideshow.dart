// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../stores/store.dart';
import '../styles/common.dart' as style;
import '../utils/image_provider.dart' as imageProvider;
import 'askquestion.dart';
import 'questionlist.dart';
import 'slideshow_immersive.dart';
import 'syncslides_page.dart';

final GlobalKey _scaffoldKey = new GlobalKey();

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
        key: _scaffoldKey,
        body: new Material(
            child:
                new SlideShow(appActions, appState, appState.decks[_deckId])));
  }
}

class SlideShow extends StatelessComponent {
  AppActions _appActions;
  AppState _appState;
  DeckState _deckState;
  NavigatorState _navigator;
  int _currSlideNum;

  SlideShow(this._appActions, this._appState, this._deckState);

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
    var image = new Flexible(child: _buildImage(), flex: 5);
    var actions = new Flexible(child: _buildActions(), flex: 1);
    var notes = new Flexible(child: _buildNotes(), flex: 3);
    var nav = new Flexible(child: new Row(_buildThumbnailNavs()), flex: 3);

    var items = [image, actions, notes, nav];

    var footer = _buildFooter();
    if (footer != null) {
      items.add(footer);
    }

    var layout = new Column(items, alignItems: FlexAlignItems.stretch);

    return layout;
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    var notes = new Flexible(child: _buildNotes(), flex: 5);
    var nav = new Flexible(child: new Column(_buildThumbnailNavs()), flex: 8);

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

    var footer = _buildFooter();
    if (footer != null) {
      layout = new Column([new Flexible(child: layout, flex: 8), footer],
          alignItems: FlexAlignItems.stretch);
    }

    return layout;
  }

  List<Widget> _buildThumbnailNavs() {
    return <Widget>[
      _buildThumbnailNav(_currSlideNum - 1, 'Previous'),
      _buildThumbnailNav(_currSlideNum + 1, 'Next')
    ];
  }

  Widget _buildImage() {
    var provider = imageProvider.getSlideImage(
        _deckState.deck.key, _deckState.slides[_currSlideNum]);

    var image = new AsyncImage(provider: provider, fit: ImageFit.scaleDown);

    // If not driving the presentation, tapping the image navigates to the immersive mode.
    if (_deckState.presentation == null ||
        !_deckState.presentation.isDriving(_appState.user)) {
      image = new InkWell(child: image, onTap: () {
        _navigator.push(new MaterialPageRoute(
            builder: (context) =>
                new SlideshowImmersivePage(_deckState.deck.key)));
      });
    }

    var counter = _buildBubbleOverlay(
        '${_currSlideNum + 1} of ${_deckState.slides.length}', 0.5, 0.98);
    image = new Stack([image, counter]);

    return new ClipRect(child: image);
  }

  Widget _buildNotes() {
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

  Widget _buildThumbnailNav(int slideNum, String label) {
    var container;

    if (slideNum >= 0 && slideNum < _deckState.slides.length) {
      var thumbnail = new AsyncImage(
          provider: imageProvider.getSlideImage(
              _deckState.deck.key, _deckState.slides[slideNum]),
          height: style.Size.thumbnailNavHeight,
          fit: ImageFit.scaleDown);

      container = new InkWell(child: thumbnail, onTap: () {
        _appActions.setCurrSlideNum(_deckState.deck.key, slideNum);
      });
    } else {
      // Empty grey placeholder.
      container = new Container(
          decoration: new BoxDecoration(
              backgroundColor: style.theme.primarySwatch[100]));
    }

    var nextPreviousBubble = _buildBubbleOverlay(label, 0.5, 0.05);
    container = new Stack([container, nextPreviousBubble]);
    container = new ClipRect(child: container);

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
    _buildActions_question(left, right);
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

  void _buildActions_question(List<Widget> left, List<Widget> right) {
    if (_deckState.presentation == null) {
      return;
    }

    // Presentation over is taken to a list of questions view.
    if (_deckState.presentation.isOwner) {
      var numQuestions = new FloatingActionButton(
          child: new Text(_deckState.presentation.questions.length.toString(),
              style: style.theme.primaryTextTheme.title));
      // TODO(aghassemi): Find a better way. Scaling down a FAB and
      // using transform to position it does not seem to be the best approach.
      final Matrix4 moveUp = new Matrix4.identity().translate(-95.0, 25.0);
      final Matrix4 scaleDown = new Matrix4.identity().scale(0.3);
      numQuestions = new Transform(child: numQuestions, transform: moveUp);
      numQuestions = new Transform(child: numQuestions, transform: scaleDown);

      var questions = new InkWell(
          child: new Icon(icon: 'communication/live_help'), onTap: () {
        _navigator.push(new MaterialPageRoute(
            builder: (context) => new QuestionListPage(_deckState.deck.key)));
      });

      left.add(questions);
      left.add(numQuestions);
    } else {
      // Audience is taken to ask a question view.
      var route = new MaterialPageRoute(
          builder: (context) =>
              new AskQuestionPage(_deckState.deck.key, _currSlideNum));

      var askQuestion = new InkWell(
          child: new Icon(icon: 'communication/live_help'), onTap: () {
        _navigator.push(route);
      });
      left.add(askQuestion);
    }
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
    if (_deckState.presentation != null &&
        _deckState.presentation.isDriving(_appState.user)) {
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

  Widget _buildFooter() {
    if (_deckState.presentation == null) {
      return null;
    }

    // Owner and not driving?
    if (_deckState.presentation.isOwner &&
        !_deckState.presentation.isDriving(_appState.user)) {
      SnackBarAction resume =
          new SnackBarAction(label: 'RESUME', onPressed: () {
        _appActions.setDriver(_deckState.deck.key, _appState.user);
      });

      return _buildSnackbarFooter('You have handed off control.',
          action: resume);
    }

    // Driving but not the owner?
    if (!_deckState.presentation.isOwner &&
        _deckState.presentation.isDriving(_appState.user)) {
      return _buildSnackbarFooter('You are now driving the presentation.');
    }

    return null;
  }

  _buildActions_addMargin(List<Widget> actions) {
    return actions
        .map(
            (w) => new Container(child: w, margin: style.Spacing.actionsMargin))
        .toList();
  }

  Widget _buildBubbleOverlay(String text, double xOffset, double yOffset) {
    return new Align(
        child: new Container(
            child: new DefaultTextStyle(
                child: new Text(text), style: Typography.white.body1),
            decoration: new BoxDecoration(
                borderRadius: 50.0, // Make the bubble round.
                backgroundColor:
                    style.Box.bubbleOverlayBackground), // Transparent gray.
            padding: new EdgeDims.symmetric(horizontal: 5.0, vertical: 2.0)),
        alignment: new FractionalOffset(xOffset, yOffset));
  }

  _buildSnackbarFooter(String lable, {SnackBarAction action}) {
    var text = new Text(lable);
    text = new DefaultTextStyle(style: Typography.white.subhead, child: text);
    List<Widget> children = <Widget>[
      new Flexible(
          child: new Container(
              margin: style.Spacing.footerVerticalMargin,
              child: new DefaultTextStyle(
                  style: Typography.white.subhead, child: text)))
    ];

    if (action != null) {
      children.add(action);
    }

    var clipper = new ClipRect(
        child: new Material(
            elevation: 6,
            color: style.Box.footerBackground,
            child: new Container(
                margin: style.Spacing.footerHorizontalMargin,
                child: new DefaultTextStyle(
                    style: new TextStyle(color: style.theme.accentColor),
                    child: new Row(children)))));

    return new Flexible(child: clipper, flex: 1);
  }
}
