// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart' show shell;
import 'package:syncbase/syncbase_client.dart';

export 'package:syncbase/syncbase_client.dart';

const String syncbaseMojoUrl =
    'https://syncslides.mojo.v.io/packages/syncbase/mojo_services/android/syncbase_server.mojo';
const appName = 'syncslides';
const dbName = 'syncslides';

SyncbaseNoSqlDatabase _db;

// Returns the database handle for the SyncSlides app.
Future<SyncbaseNoSqlDatabase> getDatabase() async {
  if (_db != null) {
    return _db;
  }

  // Initialize Syncbase app and database.
  SyncbaseClient sbClient =
      new SyncbaseClient(shell.connectToService, syncbaseMojoUrl);
  SyncbaseApp sbApp = await _createApp(sbClient);
  _db = await _createDb(sbApp);

  return _db;
}

Future<SyncbaseApp> _createApp(SyncbaseClient sbClient) async {
  var app = sbClient.app(appName);
  if (await app.exists()) {
    return app;
  }
  await app.create(createOpenPerms());
  return app;
}

Future<SyncbaseNoSqlDatabase> _createDb(SyncbaseApp app) async {
  var db = app.noSqlDatabase(dbName);
  if (await db.exists()) {
    return db;
  }
  await db.create(createOpenPerms());
  return db;
}

const String openPermsJson =
    '{"Admin":{"In":["..."]},"Write":{"In":["..."]},"Read":{"In":["..."]},"Resolve":{"In":["..."]},"Debug":{"In":["..."]}}"';
Perms createOpenPerms() {
  return SyncbaseClient.perms(openPermsJson);
}
