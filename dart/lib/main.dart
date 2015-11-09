// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'components/deckgrid.dart';
import 'loaders/loader.dart';

void main() {
  // Start loading data.
  new Loader.singleton().loadDecks();

  runApp(new MaterialApp(
      title: 'SyncSlides',
      routes: {'/': (RouteArguments args) => new DeckGridPage()}));
}
