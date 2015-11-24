// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:convert';

// Slide represents a slide within a deck.
class Slide {
  int _num;
  int get num => _num;

  List<int> _image;
  List<int> get image => _image;

  Slide(this._num, this._image) {}

  Slide.fromJson(String json) {
    Map map = JSON.decode(json);
    _num = map['num'];
    _image = map['image'];
  }

  String toJson() {
    Map map = new Map();
    map['num'] = _num;
    map['image'] = image;
    return JSON.encode(map);
  }

  // TODO(aghassemi): Override == and hash
}
