// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart' show shell;
import 'package:logging/logging.dart';
import 'package:v23discovery/discovery.dart' as discovery;

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
discovery.Scanner _scanner = null;

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
  discovery.Service service = new discovery.Service()
    ..interfaceName = _presentationInterfaceName
    ..instanceName = presentation.key
    ..attrs = serviceAttrs
    ..addrs = [presentation.syncgroupName, presentation.thumbnailSyncgroupName];

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

// TODO(aghassemi): Remove use once
// https://github.com/vanadium/issues/issues/1071 is resolved
// Currently we need to keep this mapping since discovery's lost event only
// contains an auto generated instanceId which we need to map back to presentationId.
Map<String, String> instanceIdToPresentationIdMap = new Map();

// Transforms a stream of discovery services to PresentationAdvertisement model objects.
StreamTransformer toPresentation = new StreamTransformer.fromHandlers(
    handleData:
        (discovery.Service s, EventSink<model.PresentationAdvertisement> sink) {
  String key = s.attrs['presentationid'];
  instanceIdToPresentationIdMap[s.instanceId] = key;
  log.info('Found presentation ${s.attrs['name']} under $key.');
  // Ignore our own advertised services.
  if (_advertisers.containsKey(key)) {
    log.info('Presentation ${s.attrs['name']} was advertised by us; ignoring.');
    return;
  }

  model.Deck deck = new model.Deck(s.attrs['deckid'], s.attrs['name'],
      new model.BlobRef(s.attrs['thumbnailkey']));
  var syncgroupName = s.addrs[0];
  var thumbnailSyncgroupName = s.addrs[1];
  model.PresentationAdvertisement presentation =
      new model.PresentationAdvertisement(
          key, deck, syncgroupName, thumbnailSyncgroupName);

  sink.add(presentation);
});

// Transforms a stream of instanceIds to presentationIds.
StreamTransformer toPresentationId = new StreamTransformer.fromHandlers(
    handleData: (String instanceId, EventSink<String> sink) {
  String presentationId = instanceIdToPresentationIdMap[instanceId];
  sink.add(presentationId);
});

Future<PresentationScanner> scan() async {
  if (_scanner != null) {
    return _scanner;
  }
  var query = 'v.InterfaceName = "$_presentationInterfaceName"';
  _scanner = await _discoveryClient.scan(query);

  log.info('Scan started.');
  return new PresentationScanner._internal(
      _scanner.onFound.transform(toPresentation),
      _scanner.onLost.transform(toPresentationId));
}

Future stopScan() async {
  if (_scanner == null) {
    // No scan call has been made before.
    return;
  }
  await _scanner.stop();
  _scanner = null;
}

class PresentationScanner {
  Stream<model.PresentationAdvertisement> onFound;
  Stream<String> onLost;
  PresentationScanner._internal(this.onFound, this.onLost);
}
