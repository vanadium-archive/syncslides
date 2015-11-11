// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:convert';

// Deck represents a deck of slides.
class Deck {
  String _key;
  String get key => _key;

  String _name;
  String get name => _name;

  List<int> _thumbnail;
  List<int> get thumbnail => _thumbnail;

  Deck(this._key, this._name, this._thumbnail) {}

  Deck.fromJson(String key, String json) {
    Map map = JSON.decode(json);
    _key = key;
    _name = map['name'];
    _thumbnail = map['thumbnail'];
  }

  String toJson() {
    // NOTE(aghassemi): We never serialize the key with the object.
    Map map = new Map();
    map['name'] = name;
    map['thumbnail'] = thumbnail;
    return JSON.encode(map);
  }

  // TODO(aghassemi): Override == and hash
}
