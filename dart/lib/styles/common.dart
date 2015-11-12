// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/widgets.dart';

class Text {
  static final Color secondaryTextColor = new Color.fromARGB(70, 0, 0, 0);
  static final TextStyle titleStyle = new TextStyle(fontSize: 18.0);
  static final TextStyle subTitleStyle =
      new TextStyle(fontSize: 12.0, color: secondaryTextColor);
}

class Size {
  static const double thumbnailWidth = 250.0;
  static const double listHeight = 150.0;
  static const double thumbnailNavHeight = 150.0;
  static const double thumbnailNavWidth = 267.0;
}

class Spacing {
  static final EdgeDims normalPadding = new EdgeDims.all(10.0);
  static final EdgeDims normalMargin = new EdgeDims.all(2.0);
  static final EdgeDims listItemMargin = new EdgeDims.TRBL(3.0, 6.0, 0.0, 6.0);
  static final EdgeDims thumbnailNavMargin = new EdgeDims.all(3.0);
}
