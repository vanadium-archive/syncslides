// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import '../models/all.dart' as model;

// Represents an advertised presentation of a deck.
class PresentationAdvertisement {
  // TODO(aghassemi): Fix inconsistencies between key and id everywhere.
  String _key;
  String get key => _key;

  model.Deck _deck;
  model.Deck get deck => _deck;

  String _syncgroupName;
  String get syncgroupName => _syncgroupName;

  PresentationAdvertisement(this._key, this._deck, this._syncgroupName) {}
}
