// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library store;

import 'dart:async';
import 'dart:collection';

import '../models/all.dart' as model;
import 'utils/factory.dart' as factory;

part 'actions.dart';
part 'state.dart';

// Provides the state, actions and state change event to the application.
abstract class Store {
  static Store _singletonStore = factory.create();

  factory Store.singleton() {
    return _singletonStore;
  }

  AppActions get actions;
  AppState get state;
  Stream get onStateChange;
}
