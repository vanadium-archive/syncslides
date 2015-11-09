// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' as services;

import '../models/all.dart' as model;
import '../stores/store.dart';

import 'loader.dart';

// DemoLoader loads some sample decks and slides and randomly adds/removes
// decks based on a timer.
class DemoLoader implements Loader {
  final Store _store;
  final Random _rand;

  DemoLoader()
      : _store = new Store.singleton(),
        _rand = new Random();

  static const int numDeckSets = 2;
  Stream<model.Deck> _getSampleDecks() async* {
    for (var i = 1; i <= numDeckSets; i++) {
      yield new model.Deck('pitch$i', 'Pitch Deck #$i',
          await _getRawBytes('assets/images/sample_decks/pitch/thumb.png'));
      yield new model.Deck('baku$i', 'Baku Discovery Discussion #$i',
          await _getRawBytes('assets/images/sample_decks/baku/thumb.png'));
      yield new model.Deck('vanadium$i', 'Vanadium #$i',
          await _getRawBytes('assets/images/sample_decks/vanadium/thumb.png'));
    }
  }

  Stream<model.Slide> _getSampleSlides() async* {
    // TODO(aghassemi): We need different slides for different decks.
    // For now use Vanadium slides for all.
    for (var i = 1; i <= 6; i++) {
      yield new model.Slide(
          await _getRawBytes('assets/images/sample_decks/vanadium/$i.jpg'));
    }
  }

  Future loadDecks() async {
    // Add some initial decks.
    await for (var deck in _getSampleDecks()) {
      await _addDeck(deck);
    }

    // Periodically add or remove random decks.
    new Timer.periodic(new Duration(seconds: 2), (_) async {
      var decks = await _store.getAllDecks();
      var deckKeys = decks.map((d) => d.key);
      var removeDeck = _rand.nextBool();

      if (removeDeck && decks.length > 0) {
        _store.removeDeck(decks[_rand.nextInt(decks.length)].key);
      } else {
        await for (var deck in _getSampleDecks()) {
          if (!deckKeys.contains(deck.key)) {
            await _addDeck(deck);
            break;
          }
        }
      }
    });
  }

  Future _addDeck(model.Deck deck) async {
    await _store.addDeck(deck);
    List<model.Slide> slides = await _getSampleSlides().toList();
    await _store.setSlides(deck.key, slides);
  }

  Map<String, Uint8List> _assetCache = new Map<String, Uint8List>();
  Future<Uint8List> _getRawBytes(String url) async {
    if (_assetCache.containsKey(url)) {
      return _assetCache[url];
    }
    services.Response response = await services.fetchBody(url);
    var bytes = new Uint8List.fromList(response.body.buffer.asUint8List());
    _assetCache[url] = bytes;
    return bytes;
  }
}
