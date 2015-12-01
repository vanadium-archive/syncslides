// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:convert';

class User {
  String _name;
  String get name => _name;

  String _blessing;
  String get blessing => _blessing;

  String _deviceId;
  String get deviceId => _deviceId;

  User(this._name, this._blessing, this._deviceId);

  User.fromJson(String json) {
    Map map = JSON.decode(json);
    _name = map['name'];
    _blessing = map['blessing'];
    _deviceId = map['deviceid'];
  }

  String toJson() {
    Map map = new Map();
    map['name'] = name;
    map['blessing'] = blessing;
    map['deviceid'] = deviceId;
    return JSON.encode(map);
  }
}
