// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:convert';

class Settings {
  String _deviceId;
  String get deviceId => _deviceId;

  String _mounttable;
  String get mounttable => _mounttable;

  Settings(this._deviceId, this._mounttable);

  Settings.fromJson(String json) {
    Map map = JSON.decode(json);
    _deviceId = map['deviceid'];
    _mounttable = map['mounttable'];
  }

  String toJson() {
    Map map = new Map();
    map['deviceid'] = deviceId;
    map['mounttable'] = mounttable;
    return JSON.encode(map);
  }
}
