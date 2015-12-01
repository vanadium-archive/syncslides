// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../models/all.dart' as model;

const String settingsFilePath = '/sdcard/syncslides_settings.json';

Future<model.Settings> getSettings() async {
  String settingsJson = await new File(settingsFilePath).readAsString();
  return new model.Settings.fromJson(settingsJson);
}
