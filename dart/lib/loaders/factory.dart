// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'demo_loader.dart';
import 'loader.dart';
import 'sdcard_loader.dart';

// Factory method to create a concrete loader instance.
Loader createDemoLoader() {
  return new DemoLoader();
}

Loader createSdCardLoader() {
  return new SdCardLoader();
}
