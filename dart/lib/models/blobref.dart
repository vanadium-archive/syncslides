// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import '../stores/store.dart';

// TODO(aghassemi): Replace with the true Blob type when supported in Dart.
const int maxNumTries = 100;
const Duration interval = const Duration(milliseconds: 100);

class BlobRef {
  BlobRef(this._key);
  String _key;
  String get key => _key;

  Future<List<int>> getData() {
    var store = new Store.singleton();
    int numTries = 0;

    Future<List<int>> getBlobFromStore() async {
      return store.actions.getBlob(key);
    }

    Future<List<int>> getBlobWithRetries() async {
      // Don't fail immediately if blob is not found in store, it might be still syncing.
      try {
        numTries++;
        var data = await getBlobFromStore();
        return data;
      } catch (e) {
        if (numTries <= maxNumTries) {
          return new Future.delayed(interval, getBlobWithRetries);
        } else {
          throw new ArgumentError.value(key, 'Blob not found');
        }
      }
    }

    return getBlobWithRetries();
  }
}
