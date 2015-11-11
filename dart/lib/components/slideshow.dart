// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

import '../models/all.dart' as model;
import '../stores/store.dart';

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

    return new Block([
      image,
      new Text(_currSlideNum.toString()),
      new Row([
        new FlatButton(child: new Text("Prev"), onPressed: () {
          _store.setCurrSlideNum(config.deckId, _currSlideNum - 1);
        }),
        new FlatButton(child: new Text("Next"), onPressed: () {
          _store.setCurrSlideNum(config.deckId, _currSlideNum + 1);
        })
      ])
    ]);
  }
}
