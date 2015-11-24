// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'factory.dart' as factory;

// Loader is responsible for importing existing decks and slides into the store.
abstract class Loader {
  factory Loader.demo() {
    return factory.createDemoLoader();
  }

  factory Loader.sdcard() {
    return factory.createSdCardLoader();
  }

  Future loadDeck();
}
