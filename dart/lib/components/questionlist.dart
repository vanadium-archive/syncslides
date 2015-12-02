// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../models/all.dart' as model;
import '../stores/store.dart';
import '../styles/common.dart' as style;
import '../utils/image_provider.dart' as imageProvider;
import 'syncslides_page.dart';
import 'toast.dart' as toast;

final GlobalKey _scaffoldKey = new GlobalKey();

class QuestionListPage extends SyncSlidesPage {
  final String _deckId;

  QuestionListPage(this._deckId);

  Widget build(BuildContext context, AppState appState, AppActions appActions) {
    if (!appState.decks.containsKey(_deckId)) {
      // TODO(aghassemi): Proper error page with navigation back to main view.
      return new Text('Deck no longer exists.');
    }
    var deckState = appState.decks[_deckId];
    var presentationState = deckState.presentation;
    if (presentationState == null) {
      // TODO(aghassemi): Proper error page with navigation back to main view.
      return new Text('Not in a presentation.');
    }
    if (!presentationState.isOwner) {
      // TODO(aghassemi): Proper error page with navigation back to main view.
      return new Text('Only presentation owner can see the list of questions.');
    }

    return new Scaffold(
        key: _scaffoldKey,
        toolBar: new ToolBar(
            left: new IconButton(
                icon: 'navigation/arrow_back',
                onPressed: () => Navigator.pop(context)),
            center: new Text('Answer questions')),
        body: new Material(
            child: new QuestionList(_deckId, presentationState,
                deckState.slides, appActions, appState)));
  }
}

class QuestionList extends StatelessComponent {
  String _deckId;
  PresentationState _presentationState;
  List<model.Slide> _slides;
  AppActions _appActions;
  AppState _appState;
  QuestionList(this._deckId, this._presentationState, this._slides,
      this._appActions, this._appState);

  Widget build(BuildContext context) {
    List<Widget> questionCards = _presentationState.questions
        .map((model.Question q) => _buildQuestionCard(context, q))
        .toList();
    return new ScrollableViewport(child: new Block(questionCards));
  }

  Widget _buildQuestionCard(BuildContext context, model.Question q) {
    List<Widget> titleChildren = [
      new Text('Slide ${q.slideNum + 1}', style: style.Text.titleStyle)
    ];

    Widget jumpToSlide;
    if (_presentationState.isDriving(_appState.user)) {
      jumpToSlide = new IconButton(icon: 'av/loop', onPressed: () async {
        await _appActions.setCurrSlideNum(_deckId, q.slideNum);
        toast.info(_scaffoldKey, 'Jumped to slide ${q.slideNum + 1}');
      });
      titleChildren.add(jumpToSlide);
    }

    Widget title = new Column([
      new Text('${q.questioner.name} asked about',
          style: style.Text.subtitleStyle),
      new Row(titleChildren)
    ], alignItems: FlexAlignItems.start);

    Widget thumbnail = new Container(
        child: new AsyncImage(
            width: style.Size.questionListThumbnailWidth,
            provider:
                imageProvider.getSlideImage(_deckId, _slides[q.slideNum])));

    Widget titleAndThumbnail = new Row([
      new Flexible(child: title, flex: 2),
      new Flexible(child: thumbnail, flex: 1)
    ], alignItems: FlexAlignItems.start);

    Widget question = new Container(
        child: new BlockBody([titleAndThumbnail, new Text(q.text)]),
        padding: style.Spacing.normalPadding);

    Widget handoff = new GestureDetector(onTap: () async {
      await _appActions.setDriver(_deckId, q.questioner);
      Navigator.pop(context);
    }, child: new Container(child: new Text('HAND OFF')));

    Widget actions = new Container(
        padding: style.Spacing.normalPadding,
        decoration: new BoxDecoration(
            border: new Border(
                top: new BorderSide(color: style.theme.dividerColor))),
        child: new DefaultTextStyle(
            style: new TextStyle(color: style.theme.accentColor),
            child: new Row([handoff], justifyContent: FlexJustifyContent.end)));

    return new Card(
        child: new Container(
            child: new BlockBody([question, actions]),
            margin: style.Spacing.listItemMargin));
  }
}
