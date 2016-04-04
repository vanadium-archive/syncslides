// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/shell.dart' show shell;
import 'package:logging/logging.dart';
import 'package:mojo_services/authentication/authentication.mojom.dart' as auth;

import '../models/all.dart' as model;
import '../settings/client.dart' as settings;

final Logger log = new Logger('identity/client');

// TODO(aghassemi): Switch to using the principal service.
// See https://github.com/vanadium/issues/issues/955
const String authenticationUrl = 'mojo:authentication';

Future<model.User> getUser() async {
  model.Settings s = await settings.getSettings();

  auth.AuthenticationServiceProxy authenticator =
      new auth.AuthenticationServiceProxy.unbound();

  shell.connectToService(authenticationUrl, authenticator);
  var account = await authenticator.ptr.selectAccount(true);

  // TODO(aghassemi): How do I get the blessing name from the username?
  // I don't think the following is correct as it seems the actual blessing
  // has an app specific prefix.
  // See https://github.com/vanadium/issues/issues/955
  // See https://github.com/vanadium/issues/issues/956
  var blessing = 'dev.v.io:u:${account.username}';
  return new model.User(account.username, blessing, s.deviceId);
}
