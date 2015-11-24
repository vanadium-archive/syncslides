// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:core';

import 'package:flutter/material.dart';

import '../styles/common.dart' as style;

class Durations {
  static const Duration permanent = const Duration(days: 100);
  static const Duration long = const Duration(seconds: 5);
  static const Duration medium = kSnackBarMediumDisplayDuration;
  static const Duration short = kSnackBarShortDisplayDuration;
}

ScaffoldFeatureController _currSnackBar;

void info(GlobalKey scaffoldKey, String text,
    {Duration duration: Durations.short}) {
  _closePrevious();
  _currSnackBar = scaffoldKey.currentState
      .showSnackBar(new SnackBar(content: new Text(text), duration: duration));
}

void error(GlobalKey scaffoldKey, String text, Error err,
    {Duration duration: Durations.long}) {
  _closePrevious();
  _currSnackBar = scaffoldKey.currentState.showSnackBar(new SnackBar(
      // TODO(aghassemi): Add "Details" action to error toasts and move error text there.
      content: new Text(text + ' - ERROR: $err', style: style.Text.error),
      duration: duration));
}

void _closePrevious() {
  // TODO(aghassemi): Fix this in Flutter. Currently close() throws exception
  // if snackbar is already closed.
  try {
    _currSnackBar?.close();
  } catch (e) {}
}
