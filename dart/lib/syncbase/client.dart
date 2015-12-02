// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart' show shell;
import 'package:logging/logging.dart';
import 'package:syncbase/syncbase_client.dart';

import '../utils/errors.dart' as errorsutil;

export 'package:syncbase/syncbase_client.dart';

final Logger log = new Logger('syncbase/client');

const String syncbaseMojoUrl =
    'https://syncbase.syncslides.mojo.v.io/syncbase_server.mojo';
const appName = 'syncslides';
const dbName = 'syncslides';

SyncbaseDatabase database;

// Initializes Syncbase by creating the app and the database.
Future init() async {
  SyncbaseClient sbClient =
      new SyncbaseClient(shell.connectToService, syncbaseMojoUrl);
  SyncbaseApp sbApp = await _createApp(sbClient);
  database = await _createDb(sbApp);
}

Future createSyncgroup(
    String mounttable, String syncgroupName, prefixes) async {
  SyncbaseSyncgroup sg = database.syncgroup(syncgroupName);
  var sgSpec = SyncbaseClient.syncgroupSpec(prefixes,
      perms: createOpenPerms(), mountTables: [mounttable]);
  var myInfo = SyncbaseClient.syncgroupMemberInfo(syncPriority: 1);

  try {
    await sg.create(sgSpec, myInfo);
  } catch (e) {
    if (!errorsutil.isExistsError(e)) {
      throw e;
    }
  }

  log.info('Created syncgroup $syncgroupName');
}

Future joinSyncgroup(String syncgroupName) async {
  SyncbaseSyncgroup sg = database.syncgroup(syncgroupName);
  var myInfo = SyncbaseClient.syncgroupMemberInfo(syncPriority: 1);

  await sg.join(myInfo);
  log.info('Joined syncgroup $syncgroupName');
}

Future<SyncbaseApp> _createApp(SyncbaseClient sbClient) async {
  var app = sbClient.app(appName);
  try {
    await app.create(createOpenPerms());
  } catch (e) {
    if (!errorsutil.isExistsError(e)) {
      throw e;
    }
  }

  return app;
}

Future<SyncbaseDatabase> _createDb(SyncbaseApp app) async {
  var db = app.noSqlDatabase(dbName);
  try {
    await db.create(createOpenPerms());
  } catch (e) {
    if (!errorsutil.isExistsError(e)) {
      throw e;
    }
  }

  return db;
}

const String openPermsJson =
    '{"Admin":{"In":["..."]},"Write":{"In":["..."]},"Read":{"In":["..."]},"Resolve":{"In":["..."]},"Debug":{"In":["..."]}}"';
Perms createOpenPerms() {
  return SyncbaseClient.perms(openPermsJson);
}
