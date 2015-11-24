// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import '../../config.dart' as config;

enum KeyType { Deck, Slide, PresentationCurrSlideNum, Unknown }

KeyType getKeyType(String key) {
  if (isDeckKey(key)) {
    return KeyType.Deck;
  } else if (isSlideKey(key)) {
    return KeyType.Slide;
  } else if (isPresentationCurrSlideNumKey(key)) {
    return KeyType.PresentationCurrSlideNum;
  } else {
    return KeyType.Unknown;
  }
}

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

// Returns true if a key is for a slide.
bool isSlideKey(String key) {
  return key.contains('/slides/');
}

// Gets the deck id given a slide key.
String currSlideKeyToDeckId(String key) {
  if ((!isSlideKey(key))) {
    throw new ArgumentError("$key is not a valid slide key.");
  }
  return key.substring(0, key.indexOf('/slides/'));
}

// Gets the slide index given a slide key.
int currSlideKeyToIndex(String key) {
  if ((!isSlideKey(key))) {
    throw new ArgumentError("$key is not a valid slide key.");
  }
  var indexStr = key.substring(key.lastIndexOf('/') + 1);
  return int.parse(indexStr);
}

// TODO(aghassemi): Don't use regex, just regular split should be fine.
const String _uuidPattern = '[a-zA-Z0-9-]+';
final RegExp _currPresentationSlideNumPattern =
    new RegExp('(?:$_uuidPattern/)($_uuidPattern)(?:/currentslide)');

// Constructs a current slide number key.
String getPresentationCurrSlideNumKey(String deckId, String presentationId) {
  return '$deckId/$presentationId/currentslide';
}

// Gets the presentation id given a current slide number key.
String presentationCurrSlideNumKeyToPresentationId(String currSlideNumKey) {
  if ((!isPresentationCurrSlideNumKey(currSlideNumKey))) {
    throw new ArgumentError(
        "$currSlideNumKey is not a valid presentation current slide number key.");
  }
  return _currPresentationSlideNumPattern.firstMatch(currSlideNumKey).group(1);
}

// Returns true if a key is a current slide number key.
bool isPresentationCurrSlideNumKey(String key) {
  return _currPresentationSlideNumPattern.hasMatch(key);
}

// Constructs the Syncgroup name for a presentation.
String getPresentationSyncgroupName(String presentationId) {
  // TODO(aghassemi): Currently we are assuming the first device
  // mounts itself under the name 'syncslides' and then every other device
  // creates the Syncgroup on the first device.
  // We should have each device mount itself under a unique name and
  // to create the Syncgroup on their own instance.
  return '${config.mounttableAddr}/syncslides/%%sync/$presentationId';
}
