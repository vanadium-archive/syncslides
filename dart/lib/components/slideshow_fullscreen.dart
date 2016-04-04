// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../stores/store.dart';
import '../utils/image_provider.dart' as image_provider;
import 'slideshow.dart';

class SlideshowFullscreenPage extends SlideshowPage {
  String _deckId;

  SlideshowFullscreenPage(String deckId) : super(deckId) {
    _deckId = deckId;
  }

  @override
  Widget build(BuildContext context, AppState appState, AppActions appActions) {
    var deckState = appState.decks[_deckId];

    int currSlideNum;

    if (deckState.presentation != null &&
        deckState.presentation.isFollowingPresentation) {
      currSlideNum = deckState.presentation.currSlideNum;
    } else {
      currSlideNum = deckState.currSlideNum;
    }
    var provider = image_provider.getSlideImage(
        deckState.deck.key, deckState.slides[currSlideNum]);
    return new GestureDetector(
        child: new AsyncImage(provider: provider, fit: ImageFit.contain),
        onTap: () => Navigator.pop(context));
  }
}
