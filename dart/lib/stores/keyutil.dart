// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Constructs a slide key.
String getSlideKey(String deckId, int slideIndex) {
  return '$deckId/slides/$slideIndex';
}

// Constructs a key prefix for all slides of a deck.
String getSlidesKeyPrefix(String deckId) {
  return getDeckKeyPrefix(deckId) + 'slides/';
}

// Constructs a key prefix for a deck.
String getDeckKeyPrefix(String deckId) {
  return deckId + '/';
}

// Returns true if a key is for a deck.
bool isDeckKey(String key) {
  return !key.contains('/');
}

// Constructs a current slide number key.
String getCurrSlideNumKey(String deckId) {
  return '$deckId/currslidenum';
}

// Gets the deck id given a current slide number key.
String currSlideNumKeyToDeckId(String currSlideNumKey) {
  if ((!isCurrSlideNumKey(currSlideNumKey))) {
    throw new ArgumentError(
        "$currSlideNumKey is not a valid current slide number key.");
  }
  return currSlideNumKey.substring(0, currSlideNumKey.indexOf('/currslidenum'));
}

// Returns true if a key is a current slide number key.
bool isCurrSlideNumKey(String key) {
  return key.endsWith('/currslidenum');
}
