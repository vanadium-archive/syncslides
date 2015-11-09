// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Constructs a slide key.
String getSlideKey(String deckId, int slideIndex) {
  return '$deckId/slides/$slideIndex';
}

// Constructs prefix key for a deck.
String getDeckKeyPrefix(String deckKey) {
  return deckKey + '/';
}

// Returns true if a key is for a deck.
bool isDeckKey(String key) {
  return !key.contains('/');
}
