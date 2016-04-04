// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../models/all.dart' as model;
import '../utils/asset.dart' as assetutil;

final Logger log = new Logger('utils/image_provider');

final ImageProvider defaultImageProvider = new _RawImageProvider(
    'default_image',
    () => assetutil.getRawBytes(assetutil.defaultThumbnailAssetKey));

final ImageProvider splashBackgroundImageProvider = new _RawImageProvider(
    'splash_background',
    () => assetutil.getRawBytes(assetutil.splashBackgroundAssetKey));
final ImageProvider splashFlutterImageProvider = new _RawImageProvider(
    'splash_flutter',
    () => assetutil.getRawBytes(assetutil.splashFlutterAssetKey));
final ImageProvider splashVanadiumImageProvider = new _RawImageProvider(
    'splash_vanadium',
    () => assetutil.getRawBytes(assetutil.splashVanadiumAssetKey));

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

  @override
  Future<ImageInfo> loadImage() async {
    List<int> imageData;
    try {
      imageData = await blobFetcher();
    } catch (e) {
      log.warning('Blob for $imageKey not found.');
      imageData =
          await assetutil.getRawBytes(assetutil.defaultThumbnailAssetKey);
    }

    return new ImageInfo(
        image: await decodeImageFromList(new Uint8List.fromList(imageData)));
  }

  @override
  bool operator ==(other) =>
      other is _RawImageProvider && imageKey == other.imageKey;

  @override
  int get hashCode => imageKey.hashCode;

  @override
  String toString() => imageKey;
}
