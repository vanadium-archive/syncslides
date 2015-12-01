// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart' show shell;
import 'package:logging/logging.dart';
import 'package:v23discovery/discovery.dart' as v23discovery;

import '../models/all.dart' as model;

final Logger log = new Logger('discovery/client');

const String v23DiscoveryMojoUrl =
    'https://syncslides.mojo.v.io/packages/v23discovery/mojo_services/android/discovery.mojo';

// TODO(aghassemi): We should make this the same between Flutter and Java apps when
// they can actually talk to each other.
const String presentationInterfaceName =
    'v.io/release/projects/syncslides/dart/presentation';

StreamController<model.PresentationAdvertisement> _onFoundEmitter =
    new StreamController.broadcast();
StreamController<String> _onLostEmitter = new StreamController.broadcast();

Stream onFound = _onFoundEmitter.stream;
Stream onLost = _onLostEmitter.stream;

// TODO(aghassemi): v23discovery could really use a Dart client library.
// Keep proxy, handle pairs so we can cancel calls later.
ProxyResponseFuturePair<v23discovery.ScannerProxy,
    v23discovery.ScannerScanResponseParams> _scanCall;

Map<
        String,
        ProxyResponseFuturePair<v23discovery.AdvertiserProxy,
            v23discovery.AdvertiserAdvertiseResponseParams>> _advertiseCalls =
    new Map();

Future advertise(model.PresentationAdvertisement presentation) async {
  log.info('Started advertising ${presentation.deck.name}.');
  if (_advertiseCalls.containsKey(presentation.key)) {
    // We are already advertising for this presentation.
    return _advertiseCalls[presentation.key].responseFuture;
  }

  Map<String, String> serviceAttrs = new Map();
  serviceAttrs['deckid'] = presentation.deck.key;
  serviceAttrs['name'] = presentation.deck.name;
  serviceAttrs['thumbnailkey'] = presentation.deck.thumbnail.key;
  v23discovery.Service serviceInfo = new v23discovery.Service()
    ..instanceId = presentation.key
    ..interfaceName = presentationInterfaceName
    ..instanceName = presentation.key
    ..attrs = serviceAttrs
    ..addrs = [presentation.syncgroupName, presentation.thumbnailSyncgroupName];

  v23discovery.AdvertiserProxy advertiser =
      new v23discovery.AdvertiserProxy.unbound();
  shell.connectToService(v23DiscoveryMojoUrl, advertiser);
  Future advertiseResponseFuture = advertiser.ptr.advertise(serviceInfo, null);
  _advertiseCalls[presentation.key] =
      new ProxyResponseFuturePair(advertiser, advertiseResponseFuture);

  await advertiseResponseFuture;
  log.info('Advertised ${presentation.deck.name} under ${presentation.key}.');
}

// Tracks advertisements that are in the middle of being stopped.
Map<String, Future> _stoppingAdvertisingCalls = new Map<String, Future>();
Future stopAdvertising(String presentationId) async {
  if (!_advertiseCalls.containsKey(presentationId)) {
    // Not advertised, nothing to stop.
    return new Future.value();
  }

  if (_stoppingAdvertisingCalls.containsKey(presentationId)) {
    // Already stopping, return the exiting call future.
    return _stoppingAdvertisingCalls[presentationId];
  }

  stop() async {
    v23discovery.AdvertiserAdvertiseResponseParams advertiserResponse =
        await _advertiseCalls[presentationId].responseFuture;

    await _advertiseCalls[presentationId]
        .proxy
        .ptr
        .stop(advertiserResponse.handle);
    await _advertiseCalls[presentationId].proxy.close();
  }

  Future stoppingCall = stop();
  _stoppingAdvertisingCalls[presentationId] = stoppingCall;

  stoppingCall.then((_) {
    _advertiseCalls.remove(presentationId);
    log.info('Stopped advertising ${presentationId}.');
  }).catchError((e) {
    _stoppingAdvertisingCalls.remove(presentationId);
    throw e;
  });
}

Future startScan() async {
  if (_scanCall != null) {
    // We are already scanning.
    return _scanCall.responseFuture;
  }

  var scanner = new v23discovery.ScannerProxy.unbound();
  shell.connectToService(v23DiscoveryMojoUrl, scanner);
  v23discovery.ScanHandlerStub handlerStub =
      new v23discovery.ScanHandlerStub.unbound();
  handlerStub.impl = new ScanHandler();

  var query = 'v.InterfaceName = "$presentationInterfaceName"';
  var scannerResponseFuture = scanner.ptr.scan(query, handlerStub);
  _scanCall = new ProxyResponseFuturePair(scanner, scannerResponseFuture);

  await scannerResponseFuture;
  log.info('Scan started.');
}

// Tracks whether we are already in the middle of stopping scan.
Future _stoppingScanCall;
Future stopScan() async {
  if (_scanCall == null) {
    // No scan call has been made before or scan is already being stopped.
    return new Future.value();
  }

  if (_stoppingScanCall != null) {
    // Already stopping, return the exiting call future.
    return _stoppingScanCall;
  }

  stop() async {
    v23discovery.ScannerScanResponseParams scannerResponse =
        await _scanCall.responseFuture;

    await _scanCall.proxy.ptr.stop(scannerResponse.handle);
    await _scanCall.proxy.close();
  }

  _stoppingScanCall = stop();

  _stoppingScanCall.then((_) {
    _scanCall = null;
    log.info('Scan stopped.');
  }).catchError((e) {
    _stoppingScanCall = null;
    throw e;
  });
}

class ScanHandler extends v23discovery.ScanHandler {
  found(v23discovery.Service s) async {
    String key = s.instanceId;
    log.info('Found presentation ${s.attrs['name']} under $key.');
    // Ignore our own advertised services.
    if (_advertiseCalls.containsKey(key)) {
      log.info(
          'Presentation ${s.attrs['name']} was advertised by this device itself, ignoring it.');
      return;
    }

    model.Deck deck = new model.Deck(s.attrs['deckid'], s.attrs['name'],
        new model.BlobRef(s.attrs['thumbnailkey']));
    var syncgroupName = s.addrs[0];
    var thumbnailSyncgroupName = s.addrs[1];
    model.PresentationAdvertisement presentation =
        new model.PresentationAdvertisement(
            key, deck, syncgroupName, thumbnailSyncgroupName);

    _onFoundEmitter.add(presentation);
  }

  lost(String presentationId) {
    // Ignore our own advertised services.
    log.info('Lost presentation $presentationId.');
    _onLostEmitter.add(presentationId);
  }
}

class ProxyResponseFuturePair<T1, T2> {
  final T1 proxy;
  final Future<T2> responseFuture;
  ProxyResponseFuturePair(this.proxy, this.responseFuture);
}
