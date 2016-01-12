// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.discovery;

import java.util.ArrayList;
import java.util.List;

import io.v.android.v23.V;
import io.v.syncslides.db.VDeck;
import io.v.syncslides.db.VPerson;
import io.v.syncslides.model.Deck;
import io.v.syncslides.model.Person;
import io.v.syncslides.model.PresentationAdvertisement;
import io.v.v23.context.VContext;
import io.v.v23.discovery.Attributes;
import io.v.v23.discovery.Service;
import io.v.v23.discovery.VDiscovery;
import io.v.v23.naming.Endpoint;
import io.v.v23.rpc.Server;
import io.v.v23.rpc.ServerCall;
import io.v.v23.security.BlessingPattern;
import io.v.v23.security.VSecurity;
import io.v.v23.verror.VException;

/**
 * Advertises a live presentation using Vanadium Discovery.  Additionally, it starts an
 * RPC service to provide extra details about the presentation to scanners.
 */
class RpcAdvertiser {
    private static final List<BlessingPattern> NO_PATTERNS = new ArrayList<>();
    private static final String NO_MOUNT = "";

    private final VContext mVContext;
    private final VDiscovery mDiscovery;
    private final PresentationAdvertisement mAdvertisement;

    RpcAdvertiser(VContext vContext, VDiscovery discovery,
                  PresentationAdvertisement advertisement) {
        mVContext = vContext;
        mDiscovery = discovery;
        mAdvertisement = advertisement;
    }

    void start() throws VException {
        Server server = V.getServer(
                V.withNewServer(
                        mVContext, NO_MOUNT, new MyLivePresentationServer(),
                        VSecurity.newAllowEveryoneAuthorizer()));
        List<String> addresses = new ArrayList<>();
        for (Endpoint point : server.getStatus().getEndpoints()) {
            addresses.add(point.toString());
        }
        // InstanceId and InstanceName are left unset.
        Service service = new Service();
        service.setAddrs(addresses);
        service.setInterfaceName(RpcPresentationDiscovery.INTERFACE_NAME);
        Attributes attrs = new Attributes();
        // RpcScanner will filter out any advertisements that have the same device id
        // because the user doesn't want to see his own advertisements.
        attrs.put(RpcPresentationDiscovery.DEVICE_ID_ATTRIBUTE,
                RpcPresentationDiscovery.DEVICE_ID);
        service.setAttrs(attrs);
        mDiscovery.advertise(mVContext, service, NO_PATTERNS);
    }

    private class MyLivePresentationServer implements LivePresentationServer {
        @Override
        public PresentationInfo getInfo(VContext ctx, ServerCall call) throws VException {
            Person person = mAdvertisement.getPresenter();
            VPerson vPerson = new VPerson(person.getBlessing(), person.getName());

            Deck deck = mAdvertisement.getDeck();
            VDeck vDeck = new VDeck(deck.getTitle(), deck.getThumbData());

            return new PresentationInfo(
                    vPerson, deck.getId(), vDeck, mAdvertisement.getSyncgroupName());
        }
    }
}
