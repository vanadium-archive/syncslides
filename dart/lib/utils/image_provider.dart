// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../models/all.dart' as model;
import '../utils/asset.dart' as assetutil;

final Logger log = new Logger('utils/image_provider');

final ImageProvider defaultImageProvider = new _RawImageProvider(
    'default_image',
    () => assetutil.getRawBytes(assetutil.defaultThumbnailAssetKey));

ImageProvider getDeckThumbnailImage(model.Deck deck) {
  if (deck == null) {
    throw new ArgumentError.notNull('deck');
  }

  return new _RawImageProvider('thumbnail_${deck.key}', deck.thumbnail.getData);
}

ImageProvider getSlideImage(String deckId, model.Slide slide) {
  if (deckId == null) {
    throw new ArgumentError.notNull('deckId');
  }
  if (slide == null) {
    throw new ArgumentError.notNull('slide');
  }

  return new _RawImageProvider(
      'slide_${deckId}_${slide.num}', slide.image.getData);
}

typedef Future<List<int>> BlobFetcher();

class _RawImageProvider implements ImageProvider {
  final String imageKey;
  final BlobFetcher blobFetcher;

  _RawImageProvider(this.imageKey, this.blobFetcher);

  Future<ui.Image> loadImage() async {
    List<int> imageData;
    try {
      imageData = await blobFetcher();
    } catch (e) {
      log.warning('Blob for ${imageKey} not found.');
      imageData =
          await assetutil.getRawBytes(assetutil.defaultThumbnailAssetKey);
    }

    return await decodeImageFromList(new Uint8List.fromList(imageData));
  }

  bool operator ==(other) =>
      other is _RawImageProvider && imageKey == other.imageKey;
  int get hashCode => imageKey.hashCode;
  String toString() => imageKey;
}
