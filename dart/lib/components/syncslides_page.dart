// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../stores/store.dart';

typedef Widget SyncSlidesPageBuilder(
    BuildContext context, AppState appState, AppActions appActions);

// The base class for every page.
// Responsible for watching state changes from the store and passing
// the state and actions to the build function of descendant components.
abstract class SyncSlidesPage extends StatefulComponent {
  build(BuildContext context, AppState appState, AppActions appActions);
  initState(AppState appState, AppActions appActions) {}

  _SyncSlidesPage createState() => new _SyncSlidesPage();
}

class _SyncSlidesPage extends State<SyncSlidesPage> {
  Store _store = new Store.singleton();
  AppState _state;
  StreamSubscription _onStateChangeSubscription;

  void _updateState(AppState newState) {
    setState(() => _state = newState);
  }

  @override
  void initState() {
    super.initState();
    config.initState(_store.state, _store.actions);
    _state = _store.state;
    _onStateChangeSubscription = _store.onStateChange.listen(_updateState);
  }

  @override
  void dispose() {
    _onStateChangeSubscription.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return config.build(context, _state, _store.actions);
  }
}
