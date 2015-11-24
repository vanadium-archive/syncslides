// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../models/all.dart' as model;

ImageProvider getDeckThumbnailImage(model.Deck deck) {
  return new _RawImageProvider('thumbnail_${deck.key}', deck.thumbnail);
}

ImageProvider getSlideImage(String deckId, model.Slide slide) {
  return new _RawImageProvider('slide_${deckId}_$slide.num', slide.image);
}

class _RawImageProvider implements ImageProvider {
  final String imageKey;
  final List<int> imageData;

  _RawImageProvider(this.imageKey, this.imageData);

  Future<ui.Image> loadImage() async {
    return await decodeImageFromList(new Uint8List.fromList(imageData));
  }

  bool operator ==(other) =>
      other is _RawImageProvider && imageKey == other.imageKey;
  int get hashCode => imageKey.hashCode;
  String toString() => imageKey;
}
