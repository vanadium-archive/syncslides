// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'loader_factory.dart' as loaderFactory;

// Loader is responsible for importing existing decks and slides into the store.
abstract class Loader {
  static Loader _singletonLoader = loaderFactory.create();

  factory Loader.singleton() {
    return _singletonLoader;
  }

  Future addDeck();
}
