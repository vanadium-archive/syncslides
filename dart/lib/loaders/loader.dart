// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as pathutil;

import '../models/all.dart' as model;
import '../stores/store.dart';
import '../stores/utils/key.dart' as keyutil;
import '../utils/uuid.dart' as uuidutil;

final Logger log = new Logger('loader');

const String _baseDecksPath = '/sdcard/syncslides/decks';
Directory _baseDecksDir = new Directory(_baseDecksPath);

// Loader is responsible for importing existing decks and slides into the store.
class Loader {
  final Store _store = new Store.singleton();
  static Loader _singletonLoader = new Loader._internal();

  factory Loader.singleton() {
    return _singletonLoader;
  }

  Loader._internal();

  // Loads all the decks in /sdcard/syncslides/decks
  // Name of each deck is the name of its directory.
  // Slide image files must be numbered.
  // First slide is used as the thumbnail.
  // Example:
  // /sdcard/syncslides/decks/Foo
  //    /sdcard/syncslides/decks/Foo/1.png
  //    /sdcard/syncslides/decks/Foo/2.png
  // /sdcard/syncslides/decks/Bar
  //    /sdcard/syncslides/decks/Bar/1.gif
  //
  // TODO(aghassemi): Replace with a Path Selector dialog.
  Future loadDeck() async {
    if (!await _baseDecksDir.exists()) {
      log.warning('Default $_baseDecksPath directory does not exist.');
      return;
    }

    Stream allDecksDir = _baseDecksDir.list();
    await for (FileSystemEntity fsEntity in allDecksDir) {
      if (!(fsEntity is Directory)) {
        log.warning(
            'Ignoring non-directory ${pathutil.basename(fsEntity.path)} in $_baseDecksPath');
        continue;
      }
      _loadDeck(fsEntity.path);
    }
  }

  Future _loadDeck(String path) async {
    var deckName = pathutil.basename(path);
    var deckId = uuidutil.createUuid();

    Directory deckDir = new Directory(path);
    List<model.Slide> slides = new List();
    await for (FileSystemEntity fsEntity in deckDir.list()) {
      if (!(fsEntity is File)) {
        log.warning(
            'Ignoring non-file ${pathutil.basename(fsEntity.path)} in $path');
        continue;
      }
      File slideFile = fsEntity as File;
      var slideNum;
      try {
        String slideName = pathutil.basenameWithoutExtension(slideFile.path);
        slideNum = int.parse(slideName);
        slideNum--; // Zero based index.
      } catch (e) {
        throw new ArgumentError(
            "Filename ${pathutil.basename(slideFile.path)} for a slide must be a number.");
      }

      // Create the slide object.
      List<int> slideBytes = await slideFile.readAsBytes();
      var blobRef = new model.BlobRef(
          keyutil.getDeckBlobKey(deckId, uuidutil.createUuid()));
      await _store.actions.putBlob(blobRef.key, slideBytes);
      model.Slide slide = new model.Slide(slideNum, blobRef);
      slides.add(slide);
    }

    if (slides.isEmpty) {
      log.warning('No image files found in $path.');
      return;
    }

    slides.sort((model.Slide s1, model.Slide s2) => s1.num.compareTo(s2.num));

    // Use the first slide as thumbnail.
    model.BlobRef thumbnailBlobRef = slides.first.image;
    var deck = new model.Deck(deckId, deckName, thumbnailBlobRef);

    await _store.actions.addDeck(deck);
    await _store.actions.setSlides(deck.key, slides);
  }
}
