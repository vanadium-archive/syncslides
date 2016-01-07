// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:mojo/core.dart';

import 'package:flutter/services.dart' as services;

Future<Uint8List> getRawBytes(String assetKey) async {
  MojoDataPipeConsumer pipe = await services.rootBundle.load(assetKey);
  ByteData data = await DataPipeDrainer.drainHandle(pipe);
  Uint8List bytes = new Uint8List.fromList(data.buffer.asUint8List());
  return bytes;
}

String defaultThumbnailAssetKey = 'assets/images/defaults/thumbnail.png';
String splashBackgroundAssetKey = 'assets/images/splash/background.png';
String splashVanadiumAssetKey = 'assets/images/splash/vanadium.png';
String splashFlutterAssetKey = 'assets/images/splash/flutter.png';
