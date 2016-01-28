// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

Widget stopWrapping(Widget child) {
  // TODO(aghassemi): There is no equivalent of CSS's white-space: nowrap,
  // overflow: hidden or text-overflow: ellipsis in Flutter yet.
  // This workaround simulates white-space: nowrap and overflow: hidden.
  // See https://github.com/flutter/flutter/issues/417
  return new Viewport(child: child, scrollDirection: Axis.horizontal);
}
