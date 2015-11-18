// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' as services;

Map<String, Uint8List> _assetCache = new Map<String, Uint8List>();
Future<Uint8List> getRawBytes(String url) async {
  if (_assetCache.containsKey(url)) {
    return _assetCache[url];
  }
  services.Response response = await services.fetchBody(url);
  var bytes = new Uint8List.fromList(response.body.buffer.asUint8List());
  _assetCache[url] = bytes;
  return bytes;
}

String defaultThumbnailUrl = 'assets/images/defaults/thumbnail.png';
