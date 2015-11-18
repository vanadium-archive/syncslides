// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:uuid/uuid.dart';

Uuid _uuid = new Uuid();

// Creates a universally unique identifier.
String createUuid() {
  return _uuid.v4();
}
