// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:convert';

// Slide represents an independent slide without ties to a specific deck.
class Slide {
  List<int> _image;
  List<int> get image => _image;

  Slide(this._image) {}

  Slide.fromJson(String json) {
    Map map = JSON.decode(json);
    _image = map['image'];
  }

  String toJson() {
    Map map = new Map();
    map['image'] = image;
    return JSON.encode(map);
  }
}
