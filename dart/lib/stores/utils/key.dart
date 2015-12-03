// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

enum KeyType {
  Deck,
  Slide,
  PresentationCurrSlideNum,
  PresentationDriver,
  PresentationQuestion,
  Unknown
}

KeyType getKeyType(String key) {
  if (isDeckKey(key)) {
    return KeyType.Deck;
  } else if (isSlideKey(key)) {
    return KeyType.Slide;
  } else if (isPresentationCurrSlideNumKey(key)) {
    return KeyType.PresentationCurrSlideNum;
  } else if (isPresentationDriverKey(key)) {
    return KeyType.PresentationDriver;
  } else if (isPresentationQuestionKey(key)) {
    return KeyType.PresentationQuestion;
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

// Constructs a key prefix for a presentation.
String getPresentationPrefix(String deckId, String presentationId) {
  return '$deckId/$presentationId';
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
    throw new ArgumentError('$key is not a valid slide key.');
  }
  return key.substring(0, key.indexOf('/slides/'));
}

// Gets the slide index given a slide key.
int currSlideKeyToIndex(String key) {
  if ((!isSlideKey(key))) {
    throw new ArgumentError('$key is not a valid slide key.');
  }
  var indexStr = key.substring(key.lastIndexOf('/') + 1);
  return int.parse(indexStr);
}

// TODO(aghassemi): Don't use regex, just regular split should be fine.
const String _uuidPattern = '[a-zA-Z0-9-]+';
final RegExp _currPresentationSlideNumPattern =
    new RegExp('($_uuidPattern)(?:/$_uuidPattern)(?:/currentslide)');

// Constructs a current slide number key.
String getPresentationCurrSlideNumKey(String deckId, String presentationId) {
  return '$deckId/$presentationId/currentslide';
}

// Gets the deck id given a current slide number key.
String presentationCurrSlideNumKeyToDeckId(String currSlideNumKey) {
  if ((!isPresentationCurrSlideNumKey(currSlideNumKey))) {
    throw new ArgumentError(
        '$currSlideNumKey is not a valid presentation current slide number key.');
  }
  return _currPresentationSlideNumPattern.firstMatch(currSlideNumKey).group(1);
}

// Returns true if a key is a current slide number key.
bool isPresentationCurrSlideNumKey(String key) {
  return _currPresentationSlideNumPattern.hasMatch(key);
}

// TODO(aghassemi): Don't use regex, just regular split should be fine.
final RegExp _presentationDriverPattern =
    new RegExp('($_uuidPattern)(?:/$_uuidPattern)(?:/driver)');
// Constructs a presentation driver key.
String getPresentationDriverKey(String deckId, String presentationId) {
  return '$deckId/$presentationId/driver';
}

// Gets the deck id given a presentation driver key.
String presentationDriverKeyToDeckId(String driverKey) {
  if ((!isPresentationDriverKey(driverKey))) {
    throw new ArgumentError(
        '$driverKey is not a valid presentation driver key.');
  }
  return _presentationDriverPattern.firstMatch(driverKey).group(1);
}

// Returns true if a key is a presentation driver key.
bool isPresentationDriverKey(String key) {
  return _presentationDriverPattern.hasMatch(key);
}

// TODO(aghassemi): Don't use regex, just regular split should be fine.
final RegExp _presentationQuestionPattern = new RegExp(
    '($_uuidPattern)(?:/$_uuidPattern)(?:/questions/)($_uuidPattern)');
String getPresentationQuestionKey(
    String deckId, String presentationId, String questionId) {
  return '$deckId/$presentationId/questions/$questionId';
}

String presentationQuestionKeyToDeckId(String key) {
  if ((!isPresentationQuestionKey(key))) {
    throw new ArgumentError('$key is not a valid presentation question key.');
  }
  return _presentationQuestionPattern.firstMatch(key).group(1);
}

String presentationQuestionKeyToQuestionId(String key) {
  if ((!isPresentationQuestionKey(key))) {
    throw new ArgumentError('$key is not a valid presentation question key.');
  }
  return _presentationQuestionPattern.firstMatch(key).group(2);
}

// Returns true if a key is a presentation question key.
bool isPresentationQuestionKey(String key) {
  return _presentationQuestionPattern.hasMatch(key);
}

// Constructs a blob key specific to a deck.
String getDeckBlobKey(String deckId, String blobId) {
  return '$deckId/$blobId';
}
