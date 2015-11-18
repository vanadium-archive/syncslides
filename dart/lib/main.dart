// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'styles/common.dart' as style;
import 'components/deckgrid.dart';

void main() {
  _initLogging();

  runApp(new MaterialApp(
      theme: style.theme,
      title: 'SyncSlides',
      routes: {'/': (RouteArguments args) => new DeckGridPage()}));
}

void _initLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('\nSyncSlides: ${rec.time}: ${rec.message}');
  });
}
