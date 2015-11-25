// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import '../models/all.dart' as model;
import '../stores/store.dart';
import '../styles/common.dart' as style;
import '../utils/image_provider.dart' as imageProvider;
import 'slideshow.dart';
import 'syncslides_page.dart';
import 'toast.dart' as toast;

final GlobalKey _scaffoldKey = new GlobalKey();

class SlideListPage extends SyncSlidesPage {
  final String _deckId;

  SlideListPage(this._deckId);

  Widget build(BuildContext context, AppState appState, AppActions appActions) {
    if (!appState.decks.containsKey(_deckId)) {
      // TODO(aghassemi): Proper error page with navigation back to main view.
      return new Text('Deck no longer exists.');
    }

    var deckState = appState.decks[_deckId];
    var slides = deckState.slides;
    return new Scaffold(
        key: _scaffoldKey,
        toolBar: new ToolBar(
            left: new IconButton(
                icon: 'navigation/arrow_back',
                onPressed: () => Navigator.of(context).pop()),
            center: new Text(deckState.deck.name)),
        floatingActionButton: _buildPresentFab(context, appState, appActions),
        body: new Material(child: new SlideList(_deckId, slides, appActions)));
  }

  _buildPresentFab(
      BuildContext context, AppState appState, AppActions appActions) {
    var deckState = appState.decks[_deckId];
    if (deckState.presentation != null) {
      // Can't present when already in a presentation.
      return null;
    }

    return new FloatingActionButton(
        child: new Icon(icon: 'navigation/arrow_forward'), onPressed: () async {
      toast.info(_scaffoldKey, 'Starting presentation...',
          duration: toast.Durations.permanent);

      try {
        await appActions.startPresentation(_deckId);
        toast.info(_scaffoldKey, 'Presentation started.');

        Navigator.of(context).push(new MaterialPageRoute(
            builder: (context) => new SlideshowPage(_deckId)));
      } catch (e) {
        toast.error(_scaffoldKey, 'Failed to start presentation.', e);
      }
    });
  }
}

class SlideList extends StatelessComponent {
  String _deckId;
  List<model.Slide> _slides = new List<model.Slide>();
  AppActions _appActions;
  SlideList(this._deckId, this._slides, this._appActions);

  Widget build(BuildContext context) {
    NavigatorState navigator = Navigator.of(context);
    return new ScrollableList(
        itemExtent: style.Size.listHeight,
        items: _slides,
        itemBuilder: (context, value, index) =>
            _buildSlide(context, _deckId, index, value, onTap: () {
              _appActions.setCurrSlideNum(_deckId, index);

              navigator.push(new MaterialPageRoute(
                  builder: (context) => new SlideshowPage(_deckId)));
            }));
  }
}

Widget _buildSlide(
    BuildContext context, String deckId, int slideIndex, model.Slide slideData,
    {Function onTap}) {
  var thumbnail = new AsyncImage(
      provider: imageProvider.getSlideImage(deckId, slideData),
      height: style.Size.listHeight,
      fit: ImageFit.cover);

  thumbnail = new Flexible(child: thumbnail);

  var title = new Text('Slide $slideIndex', style: style.Text.subtitleStyle);
  var notes = new Text(
      'This is the teaser slide. It should be memorable and descriptive.');
  var titleAndNotes = new Flexible(
      child: new Container(
          child: new Column([title, notes], alignItems: FlexAlignItems.start),
          padding: style.Spacing.normalPadding));

  var card = new Container(
      child: new Card(child: new Row([thumbnail, titleAndNotes])),
      margin: style.Spacing.listItemMargin);

  var listItem = new InkWell(
      key: new Key(slideIndex.toString()), child: card, onTap: onTap);

  return listItem;
}
