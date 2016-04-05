// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/shell.dart' show shell;
import 'package:logging/logging.dart';
import 'package:v23discovery/discovery.dart' as discovery;

export 'package:v23discovery/discovery.dart' show UpdateTypes;

import '../models/all.dart' as model;

final Logger log = new Logger('discovery/client');

const String _discoveryMojoUrl =
    'https://discovery.syncslides.mojo.v.io/discovery.mojo';

// TODO(aghassemi): We should make this the same between Flutter and Java apps when
// they can actually talk to each other.
const String _presentationInterfaceName =
    'v.io/release/projects/syncslides/dart/presentation';

final discovery.Client _discoveryClient =
    new discovery.Client(shell.connectToService, _discoveryMojoUrl);

final Map<String, discovery.Advertiser> _advertisers = new Map();
discovery.Scanner _scanner;

Future advertise(model.PresentationAdvertisement presentation) async {
  if (_advertisers.containsKey(presentation.key)) {
    return _advertisers[presentation.key];
  }

  log.info('Started advertising ${presentation.deck.name}.');

  Map<String, String> serviceAttrs = new Map();
  serviceAttrs['deckid'] = presentation.deck.key;
  serviceAttrs['name'] = presentation.deck.name;
  serviceAttrs['thumbnailkey'] = presentation.deck.thumbnail.key;
  serviceAttrs['presentationid'] = presentation.key;
  discovery.Advertisement service = new discovery.Advertisement(
      _presentationInterfaceName,
      [presentation.syncgroupName, presentation.thumbnailSyncgroupName])
    ..attributes = serviceAttrs;

  _advertisers[presentation.key] = await _discoveryClient.advertise(service);

  log.info('Advertised ${presentation.deck.name} under ${presentation.key}.');
}

Future stopAdvertising(String presentationId) async {
  if (!_advertisers.containsKey(presentationId)) {
    // Not advertised, nothing to stop.
    return;
  }
  await _advertisers[presentationId].stop();
  _advertisers.remove(presentationId);
}

// Transforms a stream of discovery services to PresentationAdvertisement model objects.
StreamTransformer toPresentationUpdate = new StreamTransformer.fromHandlers(
    handleData: (discovery.Update u, EventSink<PresentationUpdate> sink) {
  String key = u.attributes['presentationid'];
  log.info('Found presentation ${u.attributes['name']} under $key.');
  // Ignore our own advertised services.
  if (_advertisers.containsKey(key)) {
    log.info(
        'Presentation ${u.attributes['name']} was advertised by us; ignoring.');
    return;
  }

  model.Deck deck = new model.Deck(u.attributes['deckid'], u.attributes['name'],
      new model.BlobRef(u.attributes['thumbnailkey']));
  var syncgroupName = u.addresses[0];
  var thumbnailSyncgroupName = u.addresses[1];
  model.PresentationAdvertisement presentation =
      new model.PresentationAdvertisement(
          key, deck, syncgroupName, thumbnailSyncgroupName);

  sink.add(new PresentationUpdate._internal(presentation, u.updateType));
});

Future<PresentationScanner> scan() async {
  var query = 'v.InterfaceName = "$_presentationInterfaceName"';
  _scanner = await _discoveryClient.scan(query);

  log.info('Scan started.');

  return new PresentationScanner._internal(
      _scanner.onUpdate.transform(toPresentationUpdate));
}

Future stopScan() async {
  if (_scanner == null) {
    // No scan call has been made before.
    return;
  }
  await _scanner.stop();
  _scanner = null;
}

class PresentationUpdate {
  model.PresentationAdvertisement presentation;
  discovery.UpdateTypes updateType;
  PresentationUpdate._internal(this.presentation, this.updateType);
}

class PresentationScanner {
  Stream<PresentationUpdate> onUpdate;
  PresentationScanner._internal(this.onUpdate);
}
