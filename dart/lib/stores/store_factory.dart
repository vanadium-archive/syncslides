// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import '../config.dart' as config;

import 'store.dart';
import 'memory_store.dart';
import 'syncbase_store.dart';

// Factory method to create a concrete store instance.
Store create() {
  if (config.SyncbaseEnabled) {
    return new SyncbaseStore();
  } else {
    return new MemoryStore();
  }
}
