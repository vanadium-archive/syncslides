// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../models/all.dart' as model;
import '../stores/store.dart';
import '../styles/common.dart' as style;
import '../utils/image_provider.dart' as imageProvider;
import 'slidelist.dart';
import 'slideshow.dart';
import 'syncslides_page.dart';
import 'toast.dart' as toast;

final GlobalKey _scaffoldKey = new GlobalKey();

// DeckGridPage is the full page view of the list of decks.
class DeckGridPage extends SyncSlidesPage {
  initState(AppState appState, AppActions appActions) {
    appActions.stopAllPresentations();
  }

  Widget build(BuildContext context, AppState appState, AppActions appActions) {
    // Local decks.
    List<model.Deck> decks = appState.decks.values
        .where((DeckState d) => d.deck != null && d.presentation == null)
        .map((DeckState d) => d.deck);

    // Advertised decks.
    List<model.PresentationAdvertisement> presentations =
        appState.presentationAdvertisements.values;

    return new Scaffold(
        key: _scaffoldKey,
        toolBar: new ToolBar(center: new Text('SyncSlides')),
        floatingActionButton: new FloatingActionButton(
            child: new Icon(icon: 'content/add'), onPressed: () {
          appActions.loadDemoDeck();
        }),
        body: new Material(
            child: new DeckGrid(decks, presentations, appActions)));
  }
}

// DeckGrid is scrollable grid view of decks.
class DeckGrid extends StatelessComponent {
  AppActions _appActions;
  List<model.Deck> _decks;
  List<model.PresentationAdvertisement> _presentations;

  DeckGrid(this._decks, this._presentations, this._appActions);

  Widget build(BuildContext context) {
    List<Widget> deckBoxes = _decks.map((deck) => _buildDeckBox(context, deck));
    List<Widget> presentationBoxes = _presentations
        .map((presentation) => _buildPresentationBox(context, presentation));
    var allBoxes = new List.from(presentationBoxes)..addAll(deckBoxes);
    var grid = new Grid(allBoxes, maxChildExtent: style.Size.thumbnailWidth);
    return new ScrollableViewport(child: grid);
  }

  Widget _buildDeckBox(BuildContext context, model.Deck deckData) {
    var thumbnail =
        new AsyncImage(provider: imageProvider.getDeckThumbnailImage(deckData));
    // TODO(aghassemi): Add "Opened on" data.
    var subtitleWidget =
        new Text("Opened on Sep 12, 2015", style: style.Text.subtitleStyle);
    subtitleWidget = _stopWrapping(subtitleWidget);
    var footer = _buildBoxFooter(deckData.name, subtitleWidget);
    var box = _buildCard(deckData.key, [thumbnail, footer], () {
      Navigator.of(context).push(new MaterialPageRoute(
          builder: (context) => new SlideListPage(deckData.key)));
    });

    return box;
  }

  Widget _buildPresentationBox(
      BuildContext context, model.PresentationAdvertisement presentationData) {
    var thumbnail = new AsyncImage(
        provider: imageProvider.getDeckThumbnailImage(presentationData.deck));
    var liveBox = new Row([
      new Container(
          child: new Text("LIVE NOW", style: style.Text.liveNow),
          decoration: style.Box.liveNow,
          margin: style.Spacing.normalMargin,
          padding: style.Spacing.extraSmallPadding)
    ]);
    var footer = _buildBoxFooter(presentationData.deck.name, liveBox);
    var box = _buildCard(presentationData.key, [thumbnail, footer], () async {
      toast.info(
          _scaffoldKey, 'Joining presentation ${presentationData.deck.name}...',
          duration: toast.Durations.permanent);
      try {
        await _appActions.joinPresentation(presentationData);

        toast.info(
            _scaffoldKey, 'Joined presentation ${presentationData.deck.name}.');

        // Push slides list page first before navigating to the slideshow.
        Navigator.of(context).push(new MaterialPageRoute(
            builder: (context) =>
                new SlideListPage(presentationData.deck.key)));
        Navigator.of(context).push(new MaterialPageRoute(
            builder: (context) =>
                new SlideshowPage(presentationData.deck.key)));
      } catch (e) {
        toast.error(_scaffoldKey,
            'Failed to start presentation ${presentationData.deck.name}.', e);
      }
    });
    return box;
  }

  Widget _buildBoxFooter(String title, Widget subtitle) {
    var titleWidget = new Text(title, style: style.Text.titleStyle);
    titleWidget = _stopWrapping(titleWidget);

    var titleAndSubtitle = new Block([titleWidget, subtitle]);
    return new Container(
        child: titleAndSubtitle, padding: style.Spacing.normalPadding);
  }

  Widget _buildCard(String key, List<Widget> children, Function onTap) {
    var content = new Container(
        child: new Card(child: new Block(children)),
        margin: style.Spacing.normalMargin);

    return new InkWell(key: new Key(key), child: content, onTap: onTap);
  }

  Widget _stopWrapping(Text child) {
    // TODO(aghassemi): There is no equivalent of CSS's white-space: nowrap,
    // overflow: hidden or text-overflow: ellipsis in Flutter yet.
    // This workaround simulates white-space: nowrap and overflow: hidden.
    // See https://github.com/flutter/flutter/issues/417
    return new Viewport(
        child: child, scrollDirection: ScrollDirection.horizontal);
  }
}
