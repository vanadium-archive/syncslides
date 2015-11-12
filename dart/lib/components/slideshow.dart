// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

import '../models/all.dart' as model;
import '../stores/store.dart';
import '../styles/common.dart' as style;

class SlideshowPage extends StatelessComponent {
  final String deckId;

  SlideshowPage(this.deckId);

  Widget build(BuildContext context) {
    return new Scaffold(
        toolBar: new ToolBar(
            left: new IconButton(
                icon: 'navigation/arrow_back',
                onPressed: () => Navigator.of(context).pop())),
        body: new Material(child: new SlideShow(deckId)));
  }
}

class SlideShow extends StatefulComponent {
  final String deckId;
  SlideShow(this.deckId);

  _SlideShowState createState() => new _SlideShowState();
}

class _SlideShowState extends State<SlideShow> {
  Store _store = new Store.singleton();
  List<model.Slide> _slides;
  int _currSlideNum = 0;
  StreamSubscription _onChangeSubscription;

  void updateSlides(List<model.Slide> slides) {
    setState(() {
      _slides = slides;
    });
  }

  void updateCurrSlideNum(int newCurr) {
    setState(() {
      _currSlideNum = newCurr;
    });
  }

  @override
  void initState() {
    super.initState();
    _store.getAllSlides(config.deckId).then(updateSlides);
    _store.getCurrSlideNum(config.deckId).then(updateCurrSlideNum);
    _onChangeSubscription =
        _store.onCurrSlideNumChange(config.deckId).listen(updateCurrSlideNum);
    // TODO(aghassemi): Gracefully handle when deck is deleted during Slideshow
  }

  @override
  void dispose() {
    // Stop listening to updates from store when component is disposed.
    _onChangeSubscription.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    if (_slides == null) {
      // TODO(aghassemi): Remove when store operations become sync.
      return new Text('Loading');
    }
    var slideData = _slides[_currSlideNum];
    var image = new RawImage(
        bytes: new Uint8List.fromList(slideData.image), fit: ImageFit.contain);
    var navWidgets = [
      _buildSlideNav(_currSlideNum - 1),
      _buildSlideNav(_currSlideNum + 1)
    ];

    return new Block(
        [image, new Text(_currSlideNum.toString()), new Row(navWidgets)]);
  }

  Widget _buildSlideNav(int slideNum) {
    var card;

    if (slideNum >= 0 && slideNum < _slides.length) {
      card = _buildThumbnailNav(_slides[slideNum], onTap: () {
        _store.setCurrSlideNum(config.deckId, slideNum);
      });
    } else {
      card = new Container(
          width: style.Size.thumbnailNavWidth,
          height: style.Size.thumbnailNavHeight);
    }
    // TODO(dynin): overlay 'Previous' / 'Next' text

    return new Container(child: card, margin: style.Spacing.thumbnailNavMargin);
  }
}

Widget _buildThumbnailNav(model.Slide slideData, {Function onTap}) {
  var thumbnail = new RawImage(
      height: style.Size.thumbnailNavHeight,
      bytes: new Uint8List.fromList(slideData.image),
      fit: ImageFit.cover);

  return new InkWell(child: thumbnail, onTap: onTap);
}
