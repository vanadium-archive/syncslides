// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import '../models/all.dart' as model;
import '../stores/store.dart';
import '../styles/common.dart' as style;
import '../utils/image_provider.dart' as image_provider;
import 'slidelist.dart';
import 'slideshow.dart';
import 'syncslides_page.dart';
import 'toast.dart' as toast;
import 'utils/stop_wrapping.dart';

final GlobalKey _scaffoldKey = new GlobalKey();

// DeckGridPage is the full page view of the list of decks.
class DeckGridPage extends SyncSlidesPage {
  @override
  Widget build(BuildContext context, AppState appState, AppActions appActions) {
    // Advertised decks.
    List<model.PresentationAdvertisement> presentations =
        appState.presentationAdvertisements.values;

    // Local decks that are not advertised.
    List<model.Deck> decks = appState.decks.values
        .where((DeckState d) =>
            d.deck != null &&
            !presentations.any((model.PresentationAdvertisement p) =>
                p.deck.key == d.deck.key))
        .map((DeckState d) => d.deck);

    return new Scaffold(
        key: _scaffoldKey,
        appBar: new AppBar(title: new Text('SyncSlides')),
        floatingActionButton: new FloatingActionButton(
            child: new Icon(icon: Icons.add),
            onPressed: () {
              appActions.loadDeckFromSdCard();
            }),
        drawer: _buildDrawer(context, appState),
        body: new Material(
            child: new DeckGrid(decks, presentations, appState, appActions)));
  }

  Widget _buildDrawer(BuildContext context, AppState appState) {
    return new Drawer(child: new Block(children: [
      new DrawerItem(
          icon: Icons.account_circle,
          child: stopWrapping(
              new Text(appState.user.name, style: style.Text.titleStyle))),
      new DrawerItem(
          icon: Icons.devices,
          child: stopWrapping(new Text(appState.settings.deviceId,
              style: style.Text.titleStyle)))
    ]));
  }
}

// DeckGrid is scrollable grid view of decks.
class DeckGrid extends StatelessWidget {
  AppActions _appActions;
  AppState _appState;
  List<model.Deck> _decks;
  List<model.PresentationAdvertisement> _presentations;

  DeckGrid(this._decks, this._presentations, this._appState, this._appActions);

  @override
  Widget build(BuildContext context) {
    List<Widget> deckBoxes = _decks.map((deck) => _buildDeckBox(context, deck));
    List<Widget> presentationBoxes = _presentations
        .map((presentation) => _buildPresentationBox(context, presentation));
    var allBoxes = new List.from(presentationBoxes)..addAll(deckBoxes);
    var grid = new ScrollableGrid(
        children: allBoxes,
        delegate:
            new MaxTileWidthGridDelegate(maxTileWidth: style.Size.gridbox));
    return grid;
  }

  Widget _buildDeckBox(BuildContext context, model.Deck deckData) {
    var thumbnail = new AsyncImage(
        provider: image_provider.getDeckThumbnailImage(deckData),
        fit: ImageFit.scaleDown);

    var resumeLiveBox;
    var presentationState = _appState.decks[deckData.key]?.presentation;
    if (presentationState != null && presentationState.isOwner) {
      resumeLiveBox = new Row(children: [
        new Container(
            child: new Text("RESUME PRESENTING", style: style.Text.liveNow),
            decoration: style.Box.liveNow,
            padding: style.Spacing.extraSmallPadding)
      ]);
    }

    var footer = _buildBoxFooter(deckData.name, subtitle: resumeLiveBox);
    var box = _buildCard(deckData.key, thumbnail, footer, () {
      Navigator.push(
          context,
          new MaterialPageRoute(
              builder: (context) => new SlideListPage(deckData.key)));
    });

    return box;
  }

  Widget _buildPresentationBox(
      BuildContext context, model.PresentationAdvertisement presentationData) {
    var thumbnail = new AsyncImage(
        provider: image_provider.getDeckThumbnailImage(presentationData.deck),
        fit: ImageFit.scaleDown);
    var liveBox = new Row(children: [
      new Container(
          child: new Text("LIVE NOW", style: style.Text.liveNow),
          decoration: style.Box.liveNow,
          padding: style.Spacing.extraSmallPadding)
    ]);

    var footer = _buildBoxFooter(presentationData.deck.name, subtitle: liveBox);
    var box = _buildCard(presentationData.key, thumbnail, footer, () async {
      toast.info(
          _scaffoldKey, 'Joining presentation ${presentationData.deck.name}...',
          duration: toast.Durations.permanent);
      try {
        await _appActions.joinPresentation(presentationData);

        toast.info(
            _scaffoldKey, 'Joined presentation ${presentationData.deck.name}.');

        Navigator.openTransaction(context, (NavigatorTransaction transaction) {
          // Push slides list page first before navigating to the slideshow.
          transaction.push(new MaterialPageRoute(builder: (context) =>
              new SlideListPage(presentationData.deck.key)));
          transaction.push(new MaterialPageRoute(builder: (context) =>
              new SlideshowPage(presentationData.deck.key)));
        });
      } catch (e) {
        toast.error(_scaffoldKey,
            'Failed to start presentation ${presentationData.deck.name}.', e);
      }
    });
    return box;
  }

  Widget _buildBoxFooter(String title, {Widget subtitle}) {
    var titleChildren = [new Text(title, style: style.Text.titleStyle)];
    if (subtitle != null) {
      titleChildren.add(subtitle);
    }

    var titleContainer = new Container(
        child: new BlockBody(children: titleChildren),
        padding: style.Spacing.normalPadding);

    titleContainer = stopWrapping(titleContainer);

    return titleContainer;
  }

  Widget _buildCard(String key, Widget image, Widget footer, Function onTap) {
    image = new Flexible(child: image, flex: 1);
    footer = new Container(
        child: footer,
        constraints: new BoxConstraints.tight(
            new Size.fromHeight(style.Size.boxFooterHeight)));
    footer = new Flexible(child: footer, flex: 0);
    var content = new Container(
        child: new Card(child: new Column(
            children: [image, footer],
            crossAxisAlignment: CrossAxisAlignment.stretch)),
        margin: style.Spacing.normalMargin);

    return new InkWell(key: new Key(key), child: content, onTap: onTap);
  }
}
