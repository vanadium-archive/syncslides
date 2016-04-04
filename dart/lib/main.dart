// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'components/deckgrid.dart';
import 'stores/store.dart';
import 'styles/common.dart' as style;
import 'utils/back_button.dart' as back_button_util;
import 'utils/image_provider.dart' as image_provider;

NavigatorState _navigator;
final Completer storeStatus = new Completer();

void main() {
  Store store = new Store.singleton();
  store.init().then((_) {
    storeStatus.complete();
  });
  _initLogging();
  // TODO(aghassemi): Fix back button integration. It has been broken throwing
  // "Only one back button handler can exist per app"
  //_initBackButtonHandler();

  runApp(new MaterialApp(
      theme: style.theme,
      title: 'SyncSlides',
      routes: {'/': (BuildContext context) => new LandingPage()}));
}

class LandingPage extends StatefulWidget {
  @override
  _LandingPage createState() => new _LandingPage();
}

class _LandingPage extends State<LandingPage> {
  bool _initialized = false;

  @override
  void initState() {
    if (storeStatus.isCompleted) {
      _initialized = true;
    } else {
      storeStatus.future.then((_) {
        setState(() {
          _initialized = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return _buildSplashScreen();
    }
    _navigator =
        context.ancestorStateOfType(const TypeMatcher<NavigatorState>());
    return new DeckGridPage();
  }

  Widget _buildSplashScreen() {
    var stack = new Stack(children: [
      new AsyncImage(
          provider: image_provider.splashBackgroundImageProvider,
          fit: ImageFit.cover),
      new Row(children: [
        new AsyncImage(
            provider: image_provider.splashFlutterImageProvider,
            width: style.Size.splashLogo),
        new AsyncImage(
            provider: image_provider.splashVanadiumImageProvider,
            width: style.Size.splashLogo)
      ], mainAxisAlignment: MainAxisAlignment.center),
      new Container(
          child: new Row(
              children: [
                new Text('Loading SyncSlides...', style: style.Text.splash)
              ],
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center),
          padding: style.Spacing.normalPadding)
    ]);
    return stack;
  }
}

void _initLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('\nSyncSlides: ${rec.time}: ${rec.message}');
  });
}

void _initBackButtonHandler() {
  back_button_util.onBackButton(() {
    if (_navigator != null && _navigator.canPop()) {
      bool returnValue;
      _navigator.openTransaction((NavigatorTransaction transaction) {
        returnValue = transaction.pop(null);
      });
      return returnValue;
    }

    // Tell the app to exit.
    return false;
  });
}
