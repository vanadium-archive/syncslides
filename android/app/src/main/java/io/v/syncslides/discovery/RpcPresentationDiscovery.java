// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.discovery;

import java.util.UUID;

import io.v.android.v23.V;
import io.v.syncslides.model.DynamicList;
import io.v.syncslides.model.PresentationAdvertisement;
import io.v.v23.context.VContext;
import io.v.v23.verror.VException;

/**
 * Uses a combination of Vanadium Discovery and RPC to advertise/scan for
 * live presentations.
 */
public class RpcPresentationDiscovery implements PresentationDiscovery {

    static final String INTERFACE_NAME = "v.io/syncslides/discovery.LivePresentation";

    /**
     * Passed to both RpcScanner and RpcAdvertiser to ensure that advertisements from this
     * device don't show up in the scan.
     */
    static final String DEVICE_ID_ATTRIBUTE = "device_id";
    static final String DEVICE_ID = UUID.randomUUID().toString();

    private final VContext mContext;

    public RpcPresentationDiscovery(VContext context) {
        mContext = context;
    }

    @Override
    public DynamicList<PresentationAdvertisement> scan() {
        return new RpcScanner(mContext, V.getDiscovery(mContext), new RpcClientFactory());
    }

    @Override
    public void advertise(VContext vContext, PresentationAdvertisement advertisement)
            throws VException {
        RpcAdvertiser advertiser =
                new RpcAdvertiser(vContext, V.getDiscovery(vContext), advertisement);
        advertiser.start();
    }
}
