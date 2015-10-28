// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math' show Random;
import 'dart:convert' show UTF8;

import 'package:flutter/material.dart';

import 'package:flutter/services.dart' show embedder;
import 'package:syncbase/syncbase_client.dart' as sb;

// TODO(aghassemi) Temporary main.
void main() {
  runApp(new MaterialApp(
      title: "Flutter & Syncbase Demo",
      routes: {'/': (RouteArguments args) => new FlutterSyncbaseDemo()}));
}

class FlutterSyncbaseDemoState extends State<FlutterSyncbaseDemo> {
  List<String> activityLog = [];

  void addActivityLogItem(String item) {
    setState(() {
      activityLog.add(item);
    });
  }

  Widget build(BuildContext context) {
    return new Scaffold(
        toolBar: new ToolBar(center: new Text("Flutter & Syncbase Demo")),
        body: new Material(child: new Text(activityLog.join("\n"))));
  }
}

class FlutterSyncbaseDemo extends StatefulComponent {
  FlutterSyncbaseDemoState _state = new FlutterSyncbaseDemoState();

  FlutterSyncbaseDemo() {
    initSyncbase(_state);
  }

  FlutterSyncbaseDemoState createState() {
    return _state;
  }
}

bool initialized = false;
initSyncbase(FlutterSyncbaseDemoState state) async {
  if (initialized) {
    return;
  }

  initialized = true;
  sb.SyncbaseClient c = new sb.SyncbaseClient(embedder.connectToService,
      'https://syncslides.mojo.v.io/packages/syncbase/mojo_services/android/syncbase_server.mojo');

  sb.SyncbaseApp sbApp = await createApp(c, 'testapp');
  sb.SyncbaseNoSqlDatabase sbDb = await createDb(sbApp, 'testdb');
  sb.SyncbaseTable sbTable = await createTable(sbDb, 'testtable');

  startWatch(sbDb, sbTable, state);
  startPuts(sbTable, state);

  // Wait forever.
  await new Completer().future;

  // Looks like forever came and went.  Might as well clean up after
  // ourselves...
  await c.close();
}

startWatch(db, table, state) async {
  var s = db.watch(table.name, '', await db.getResumeMarker());
  await for (var change in s) {
    var activity =
        'GOT CHANGE: ${change.rowKey} - ${UTF8.decode(change.valueBytes)}';
    state.addActivityLogItem(activity);
    print(activity);
  }
}

var r = new Random();

startPuts(table, state) async {
  var key = r.nextInt(100000000);
  var val = r.nextInt(100000000);

  var row = table.row('k-$key');
  var activity = 'PUTTING k-$key';
  state.addActivityLogItem(activity);
  print(activity);
  await row.put(UTF8.encode('v-$val'));

  await new Future.delayed(new Duration(seconds: 2));
  startPuts(table, state);
}

String openPermsJson =
    '{"Admin":{"In":["..."]},"Write":{"In":["..."]},"Read":{"In":["..."]},"Resolve":{"In":["..."]},"Debug":{"In":["..."]}}';
sb.Perms openPerms = sb.SyncbaseClient.perms(openPermsJson);

Future<sb.SyncbaseApp> createApp(sb.SyncbaseClient c, String name) async {
  var app = c.app(name);
  var exists = await app.exists();
  if (exists) {
    print('app exists, rolling with it');
    return app;
  }
  print('app does not exist, creating it');
  await app.create(openPerms);
  return app;
}

Future<sb.SyncbaseNoSqlDatabase> createDb(
    sb.SyncbaseApp app, String name) async {
  var db = app.noSqlDatabase(name);
  var exists = await db.exists();
  if (exists) {
    print('db exists, rolling with it');
    return db;
  }
  print('db does not exist, creating it');
  await db.create(openPerms);
  return db;
}

Future<sb.SyncbaseTable> createTable(
    sb.SyncbaseNoSqlDatabase db, String name) async {
  var table = db.table(name);
  var exists = await table.exists();
  if (exists) {
    print('table exists, rolling with it');
    return table;
  }
  print('table does not exist, creating it');
  await table.create(openPerms);
  return table;
}
