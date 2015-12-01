// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import '../models/all.dart' as model;
import '../stores/store.dart';
import '../stores/utils/key.dart' as keyutil;
import '../utils/asset.dart' as assetutil;
import '../utils/uuid.dart' as uuidutil;
import 'loader.dart';

// DemoLoader loads some sample decks and slides and randomly adds/removes
// decks based on a timer.
class DemoLoader implements Loader {
  final Store _store = new Store.singleton();
  final Random _rand = new Random();

  static final List<String> thumbnails = [
    'assets/images/sample_decks/baku/thumb.png',
    'assets/images/sample_decks/vanadium/thumb.png',
    'assets/images/sample_decks/pitch/thumb.png'
  ];
  static final List<String> slides = [
    'assets/images/sample_decks/vanadium/1.jpg',
    'assets/images/sample_decks/vanadium/2.jpg',
    'assets/images/sample_decks/vanadium/3.jpg',
    'assets/images/sample_decks/vanadium/4.jpg',
    'assets/images/sample_decks/vanadium/5.jpg',
    'assets/images/sample_decks/vanadium/6.jpg'
  ];
  static final List<String> firstWords = [
    'Today\'s',
    'Yesterday\'s',
    'Ali\'s',
    'Adam\'s',
    'Misha\'s'
  ];
  static final List<String> secondWords = [
    'Presentation',
    'Slideshow',
    'Meeting',
    'Pitch',
    'Discussion',
    'Demo',
    'All Hands'
  ];

  static const int maxNumSlides = 20;

  Future<model.Deck> _getRandomDeck() async {
    var firstWord = firstWords[_rand.nextInt(firstWords.length)];
    var secondWord = secondWords[_rand.nextInt(secondWords.length)];
    var thumbnail = await assetutil
        .getRawBytes(thumbnails[_rand.nextInt(thumbnails.length)]);

    var deckId = uuidutil.createUuid();
    var blobRef = new model.BlobRef(
        keyutil.getDeckBlobKey(deckId, uuidutil.createUuid()));

    await _store.actions.putBlob(blobRef.key, thumbnail);

    return new model.Deck(deckId, '$firstWord $secondWord', blobRef);
  }

  Stream<model.Slide> _getRandomSlides(model.Deck deck) async* {
    var numSlides = _rand.nextInt(maxNumSlides);
    for (var i = 0; i < numSlides; i++) {
      var slideIndex = i % slides.length;
      var blobRef = new model.BlobRef(
          keyutil.getDeckBlobKey(deck.key, uuidutil.createUuid()));
      var image = await assetutil.getRawBytes(
          'assets/images/sample_decks/vanadium/${slideIndex + 1}.jpg');
      await _store.actions.putBlob(blobRef.key, image);
      yield new model.Slide(i, blobRef);
    }
  }

  Future loadDeck() async {
    var deck = await _getRandomDeck();
    List<model.Slide> slides = await _getRandomSlides(deck).toList();
    await _store.actions.addDeck(deck);
    await _store.actions.setSlides(deck.key, slides);
  }
}
