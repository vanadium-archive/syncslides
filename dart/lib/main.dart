// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'styles/common.dart' as style;
import 'components/deckgrid.dart';
import 'utils/back_button.dart' as backButtonUtil;

NavigatorState _navigator;

void main() {
  _initLogging();
  _initBackButtonHandler();

  runApp(new MaterialApp(
      theme: style.theme,
      title: 'SyncSlides',
      routes: {'/': (RouteArguments args) => new LandingPage()}));
}

class LandingPage extends StatelessComponent {
  Widget build(BuildContext context) {
    _navigator = Navigator.of(context);
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
    if (_navigator != null && _navigator.hasPreviousRoute) {
      _navigator.pop();
      return true;
    }

    // Tell the app to exit.
    return false;
  });
}
