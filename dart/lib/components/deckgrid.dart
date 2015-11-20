// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../loaders/loader.dart';
import '../models/all.dart' as model;
import '../stores/store.dart';
import '../styles/common.dart' as style;
import '../utils/image_provider.dart' as imageProvider;

import 'slidelist.dart';

// DeckGridPage is the full page view of the list of decks.
class DeckGridPage extends StatelessComponent {
  Loader _loader = new Loader.singleton();
  Widget build(BuildContext context) {
    return new Scaffold(
        toolBar: new ToolBar(center: new Text('SyncSlides')),
        floatingActionButton: new FloatingActionButton(
            child: new Icon(icon: 'content/add'), onPressed: () {
          _loader.addDeck();
        }),
        body: new Material(child: new DeckGrid()));
  }
}

// DeckGrid is scrollable grid view of decks.
class DeckGrid extends StatefulComponent {
  _DeckGridState createState() => new _DeckGridState();
}

class _DeckGridState extends State<DeckGrid> {
  Store _store = new Store.singleton();
  List<model.Deck> _decks = new List<model.Deck>();
  StreamSubscription _onDecksChangeSubscription;
  StreamSubscription _onStateChangeSubscription;

  void updateDecks(List<model.Deck> decks) {
    setState(() {
      _decks = decks;
    });
  }

  void _rebuild(_) {
    setState(() {});
  }

  @override
  void initState() {
    // Stop all active presentations when coming back to the decks grid page.
    _store.stopAllPresentations();
    _store.getAllDecks().then(updateDecks);
    // Update the state whenever store tells us decks have changed.
    _onDecksChangeSubscription = _store.onDecksChange.listen(updateDecks);
    _onStateChangeSubscription = _store.onStateChange.listen(_rebuild);
    super.initState();
  }

  @override
  void dispose() {
    // Stop listening to updates from store when component is disposed.
    _onDecksChangeSubscription.cancel();
    _onStateChangeSubscription.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    List<Widget> deckBoxes = _decks.map((deck) => _buildDeckBox(context, deck));
    List<Widget> presentationBoxes = _store.state.livePresentations
        .map((presentation) => _buildPresentationBox(context, presentation));
    var allBoxes = new List.from(presentationBoxes)..addAll(deckBoxes);
    var grid = new Grid(allBoxes, maxChildExtent: style.Size.thumbnailWidth);
    return new ScrollableViewport(child: grid);
  }
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
        builder: (context) => new SlideListPage(deckData.key, deckData.name)));
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
  var box = _buildCard(presentationData.key, [thumbnail, footer], () {});
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
