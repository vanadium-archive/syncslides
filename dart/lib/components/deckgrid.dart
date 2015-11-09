// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../models/all.dart' as model;
import '../stores/store.dart';
import '../styles/common.dart' as style;

import 'slidelist.dart';

// DeckGridPage is the full page view of the list of decks.
class DeckGridPage extends StatelessComponent {
  Widget build(BuildContext context) {
    return new Scaffold(
        toolBar: new ToolBar(center: new Text('SyncSlides')),
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
  StreamSubscription _onChangeSubscription;

  void updateDecks(List<model.Deck> decks) {
    setState(() {
      _decks = decks;
    });
  }

  @override
  void initState() {
    _store.getAllDecks().then(updateDecks);
    // Update the state whenever store tells us decks have changed.
    _onChangeSubscription = _store.onDecksChange.listen(updateDecks);
    super.initState();
  }

  @override
  void dispose() {
    // Stop listening to updates from store when component is disposed.
    _onChangeSubscription.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    var deckBoxes = _decks.map((deck) => _buildDeckBox(context, deck)).toList();
    var grid = new Grid(deckBoxes, maxChildExtent: style.Size.thumbnailWidth);
    return new ScrollableViewport(child: grid);
  }
}

// TODO(aghassemi): Is this approach okay? Check with Flutter team.
// Building RawImage is expensive, so we cache.
// Expando is a weak map so this does not effect GC.
Expando<Widget> weakDeckItemCache = new Expando<Widget>();
Widget _buildDeckBox(BuildContext context, model.Deck deckData) {
  var cachedWidget = weakDeckItemCache[deckData];
  if (cachedWidget != null) {
    return cachedWidget;
  }

  var thumbnail;
  if (deckData.thumbnail != null) {
    thumbnail = new RawImage(bytes: new Uint8List.fromList(deckData.thumbnail));
  } else {
    // TODO(aghassemi): Replace with a proper default thumbnail.
    thumbnail = new Text('No Thumbnail Image');
  }

  var title = new Text(deckData.name, style: style.Text.titleStyle);
  var titleAndActions =
      new Container(child: title, padding: style.Spacing.normalPadding);

  var card = new Container(
      child: new Card(child: new Block([thumbnail, titleAndActions])),
      margin: style.Spacing.normalMargin);

  var gridItem = new InkWell(child: card, onTap: () {
    Navigator.of(context).push(new PageRoute(
        builder: (context) => new SlideListPage(deckData.key, deckData.name)));
  });

  weakSlideCache[deckData] = gridItem;
  return gridItem;
}
