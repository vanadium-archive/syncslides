// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import '../store.dart';
import '../syncbase/store.dart';

// Factory method to create a concrete store instance.
Store create() {
  return new SyncbaseStore();
}
