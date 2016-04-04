// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:convert';

import 'user.dart';

class Question {
  Question(
      this._id, this._text, this._slideNum, this._questioner, this._timestamp);

  Question.fromJson(String id, String json) {
    Map map = JSON.decode(json);
    _id = id;
    _text = map['text'];
    _slideNum = map['slidenum'];
    _questioner = new User.fromJson(map['questioner']);
    _timestamp = new DateTime.fromMillisecondsSinceEpoch(map['timestamp']);
  }

  // TODO(aghassemi): Fix inconsistencies between key and id everywhere.
  String _id;
  String get id => _id;

  String _text;
  String get text => _text;

  int _slideNum;
  int get slideNum => _slideNum;

  User _questioner;
  User get questioner => _questioner;

  DateTime _timestamp;
  DateTime get timestamp => _timestamp;

  String toJson() {
    Map map = new Map();
    map['text'] = text;
    map['slidenum'] = slideNum;
    map['questioner'] = questioner.toJson();
    map['timestamp'] = timestamp.millisecondsSinceEpoch;
    return JSON.encode(map);
  }
}
