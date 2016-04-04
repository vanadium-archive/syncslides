// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

class Text {
  static final Color secondaryTextColor = Colors.grey[500];
  static final Color errorTextColor = Colors.red[500];
  static final TextStyle titleStyle = new TextStyle(fontSize: 18.0);
  static final TextStyle splash =
      new TextStyle(fontSize: 16.0, color: Colors.white);
  static final TextStyle subtitleStyle =
      new TextStyle(fontSize: 12.0, color: secondaryTextColor);
  static final TextStyle liveNow =
      new TextStyle(fontSize: 12.0, color: theme.accentColor);
  static final TextStyle error = new TextStyle(color: errorTextColor);
}

class Size {
  static const double gridbox = 250.0;
  static const double boxFooterHeight = 65.0;
  static const double listHeight = 120.0;
  static const double thumbnailNavHeight = 250.0;
  static const double questionListThumbnailWidth = 100.0;
  static const double slideListThumbnailWidth = 200.0;
  static const double splashLogo = 75.0;
}

class Spacing {
  static final EdgeInsets extraSmallPadding = new EdgeInsets.all(2.0);
  static final EdgeInsets smallPadding = new EdgeInsets.all(5.0);
  static final EdgeInsets normalPadding = new EdgeInsets.all(10.0);
  static final EdgeInsets normalMargin = new EdgeInsets.all(2.0);
  static final EdgeInsets cardMargin = new EdgeInsets.all(4.0);
  static final EdgeInsets listItemMargin =
      new EdgeInsets.fromLTRB(6.0, 3.0, 6.0, 0.0);
  static final EdgeInsets actionsMargin =
      new EdgeInsets.symmetric(horizontal: 10.0);
  static final EdgeInsets fabMargin = new EdgeInsets.only(right: 7.0);
  static final EdgeInsets footerVerticalMargin =
      const EdgeInsets.symmetric(vertical: 14.0);
  static final EdgeInsets footerHorizontalMargin =
      const EdgeInsets.symmetric(horizontal: 24.0);
}

class Box {
  static final Color bubbleOverlayBackground = new Color.fromARGB(80, 0, 0, 0);
  static final Color footerBackground = new Color(0xFF323232);
  static final BoxDecoration liveNow = new BoxDecoration(
      border: new Border.all(color: theme.accentColor), borderRadius: 2.0);
}

ThemeData theme = new ThemeData(
    primarySwatch: Colors.blueGrey, accentColor: Colors.orangeAccent[700]);
