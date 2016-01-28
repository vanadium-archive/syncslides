// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import '../stores/store.dart';
import 'syncslides_page.dart';

class AskQuestionPage extends SyncSlidesPage {
  final String _deckId;
  final int _currSlideNum;

  AskQuestionPage(this._deckId, this._currSlideNum);

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

    // TODO(aghassemi): Switch to multi-line input when support is added.
    // https://github.com/flutter/flutter/issues/627
    var input = new Input(labelText: 'Your question', autofocus: true,
        onSubmitted: (String questionText) async {
      await appActions.askQuestion(
          deckState.deck.key, _currSlideNum, questionText);

      // TODO(aghassemi): Add a 'Question submitted.' toast on the parent page.
      // Blocked on https://github.com/flutter/flutter/issues/608
      Navigator.pop(context);
    });

    var view = new Row(children: [input], alignItems: FlexAlignItems.stretch);

    return new Scaffold(
        toolBar: new ToolBar(
            left: new IconButton(
                icon: 'navigation/arrow_back',
                onPressed: () => Navigator.pop(context)),
            center: new Text('Ask a question')),
        body: new Material(child: view));
  }
}
