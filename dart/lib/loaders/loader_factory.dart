// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import '../config.dart' as config;

import 'loader.dart';
import 'demo_loader.dart';
import 'sdcard_loader.dart';

// Factory method to create a concrete loader instance.
Loader create() {
  if (config.DemoEnabled) {
    return new DemoLoader();
  } else {
    return new SdCardLoader();
  }
}
