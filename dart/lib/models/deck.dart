// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:convert';

import 'blobref.dart';

// Deck represents a deck of slides.
class Deck {
  Deck(this._key, this._name, this._thumbnail);

  Deck.fromJson(String key, String json) {
    Map map = JSON.decode(json);
    _key = key;
    _name = map['name'];
    _thumbnail = new BlobRef(map['thumbnailkey']);
  }

  String _key;
  String get key => _key;

  String _name;
  String get name => _name;

  BlobRef _thumbnail;
  BlobRef get thumbnail => _thumbnail;

  String toJson() {
    // NOTE(aghassemi): We never serialize the key with the object.
    Map map = new Map();
    map['name'] = name;
    map['thumbnailkey'] = thumbnail.key;
    return JSON.encode(map);
  }

  // TODO(aghassemi): Override == and hash
}
