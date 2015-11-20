// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

import '../models/all.dart' as model;
import '../stores/store.dart';
import '../styles/common.dart' as style;
import '../utils/image_provider.dart' as imageProvider;

import 'slideshow.dart';

// SlideListPage is the full page view of the list of slides for a deck.
class SlideListPage extends StatelessComponent {
  final String deckId;
  final String title;
  Store _store = new Store.singleton();

  SlideListPage(this.deckId, this.title);
  Widget build(BuildContext context) {
    return new Scaffold(
        toolBar: new ToolBar(
            left: new IconButton(
                icon: 'navigation/arrow_back',
                onPressed: () => Navigator.of(context).pop()),
            center: new Text(title)),
        floatingActionButton: _buildPresentFab(context),
        body: new Material(child: new SlideList(deckId)));
  }

  _buildPresentFab(BuildContext context) {
    return new FloatingActionButton(
        child: new Icon(icon: 'navigation/arrow_forward'), onPressed: () async {
      model.PresentationAdvertisement presentation =
          await _store.startPresentation(deckId);
      Navigator.of(context).push(new MaterialPageRoute(
          builder: (context) => new SlideshowPage(deckId)));
    });
  }
}

// SlideList is scrollable list view of slides for a deck.
class SlideList extends StatefulComponent {
  final String deckId;
  SlideList(this.deckId);

  _SlideListState createState() => new _SlideListState();
}

class _SlideListState extends State<SlideList> {
  Store _store = new Store.singleton();
  List<model.Slide> _slides = new List<model.Slide>();

  void updateSlides(List<model.Slide> slides) {
    setState(() {
      _slides = slides;
    });
  }

  @override
  void initState() {
    super.initState();
    _store.getAllSlides(config.deckId).then(updateSlides);
    // TODO(aghassemi): Gracefully handle when deck is deleted while in this view.
  }

  Widget build(BuildContext context) {
    return new ScrollableList(
        itemExtent: style.Size.listHeight,
        items: _slides,
        itemBuilder: (context, value, index) =>
            _buildSlide(context, config.deckId, index, index.toString(), value,
                onTap: () {
              _store.setCurrSlideNum(config.deckId, index);
              Navigator.of(context).push(new MaterialPageRoute(
                  builder: (context) => new SlideshowPage(config.deckId)));
            }));
  }
}

Widget _buildSlide(BuildContext context, String deckId, int slideIndex,
    String key, model.Slide slideData,
    {Function onTap}) {
  var thumbnail = new AsyncImage(
      provider: imageProvider.getSlideImage(deckId, slideIndex, slideData),
      height: style.Size.listHeight,
      fit: ImageFit.cover);

  thumbnail = new Flexible(child: thumbnail);

  var title = new Text('Slide $key', style: style.Text.subtitleStyle);
  var notes = new Text(
      'This is the teaser slide. It should be memorable and descriptive');
  var titleAndNotes = new Flexible(
      child: new Container(
          child: new Column([title, notes], alignItems: FlexAlignItems.start),
          padding: style.Spacing.normalPadding));

  var card = new Container(
      child: new Card(child: new Row([thumbnail, titleAndNotes])),
      margin: style.Spacing.listItemMargin);

  var listItem = new InkWell(key: new Key(key), child: card, onTap: onTap);

  return listItem;
}
