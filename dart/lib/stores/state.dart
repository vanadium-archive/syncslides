// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import '../models/all.dart' as model;

// Represents current state of the application.
class State {
  // TODO(aghassemi): The new store model is to have one state object
  // and a change event instead of async getters.
  // This model has not been implemented for decks and slides yet but
  // we are using the new model for presentation advertisements.

  // TODO(aghassemi): State needs to be deeply immutable.
  // Maybe https://github.com/google/built_value.dart can help?
  List<model.PresentationAdvertisement> livePresentations;

  State() : livePresentations = new List();
}
