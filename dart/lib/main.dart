// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'components/deckgrid.dart';
import 'stores/store.dart';
import 'styles/common.dart' as style;
import 'utils/back_button.dart' as backButtonUtil;

NavigatorState _navigator;

void main() {
  var store = new Store.singleton();
  _initLogging();
  _initBackButtonHandler();

  // TODO(aghassemi): Splash screen while store is initializing.
  store.init().then((_) => runApp(new MaterialApp(
      theme: style.theme,
      title: 'SyncSlides',
      routes: {'/': (RouteArguments args) => new LandingPage()})));
}

class LandingPage extends StatelessComponent {
  Widget build(BuildContext context) {
    _navigator = context.ancestorStateOfType(NavigatorState);
    return new DeckGridPage();
  }
}

void _initLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('\nSyncSlides: ${rec.time}: ${rec.message}');
  });
}

void _initBackButtonHandler() {
  backButtonUtil.onBackButton(() {
    if (_navigator != null) {
      bool returnValue;
      _navigator.openTransaction((NavigatorTransaction transaction) {
        returnValue = transaction.pop(null);
        if (!returnValue) {
          // pop() returns false when we popped the top-level route.
          // To stay on the landing page, we re-push its route.
          transaction.pushNamed('/');
        }
      });
      return returnValue;
    }

    // Tell the app to exit.
    return false;
  });
}
