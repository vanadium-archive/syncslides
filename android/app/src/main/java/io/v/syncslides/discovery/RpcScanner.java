// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.discovery;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.google.common.collect.Lists;
import com.google.common.collect.Sets;

import java.util.List;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.v.syncslides.db.VDeck;
import io.v.syncslides.model.Deck;
import io.v.syncslides.model.DeckImpl;
import io.v.syncslides.model.DynamicList;
import io.v.syncslides.model.ListListener;
import io.v.syncslides.model.Person;
import io.v.syncslides.model.PresentationAdvertisement;
import io.v.v23.InputChannel;
import io.v.v23.InputChannels;
import io.v.v23.VIterable;
import io.v.v23.context.CancelableVContext;
import io.v.v23.context.VContext;
import io.v.v23.discovery.Attributes;
import io.v.v23.discovery.Service;
import io.v.v23.discovery.Update;
import io.v.v23.discovery.VDiscovery;
import io.v.v23.verror.VException;

import static io.v.v23.VFutures.sync;

/**
 * Scans for live presentations using Vanadium Discovery.  When it does find those advertisements,
 * it issues an RPC to fetch the details.  The scanning is started/stopped when the first/last
 * listener is added/removed.
 */
class RpcScanner implements DynamicList<PresentationAdvertisement> {
    private static final String TAG = "RpcScanner";
    private static final String QUERY = "v.InterfaceName=\"" +
            RpcPresentationDiscovery.INTERFACE_NAME + "\"";

    private final VContext mBaseContext;
    private final VDiscovery mDiscovery;
    private final ClientFactory mClientFactory;
    private final Set<ListListener> mListeners;
    private final ExecutorService mExecutor;
    private final List<PresentationAdvertisement> mElems;
    private final Handler mHandler;
    private CancelableVContext mCurrentContext;

    public RpcScanner(VContext context, VDiscovery discovery, ClientFactory clientFactory) {
        mBaseContext = context;
        mDiscovery = discovery;
        mClientFactory = clientFactory;
        mListeners = Sets.newHashSet();
        mExecutor = Executors.newSingleThreadExecutor();
        mElems = Lists.newArrayList();
        mHandler = new Handler(Looper.getMainLooper());
    }

    @Override
    public int getItemCount() {
        return mElems.size();
    }

    @Override
    public PresentationAdvertisement get(int i) {
        return mElems.get(i);
    }

    @Override
    public void addListener(final ListListener listener) {
        mListeners.add(listener);
        if (mListeners.size() == 1) {
            // First listener.  Start the thread.
            mCurrentContext = mBaseContext.withCancel();
            mExecutor.submit(() -> scan());
        }
        mHandler.post(() -> listener.notifyDataSetChanged());
    }

    @Override
    public void removeListener(ListListener listener) {
        mListeners.remove(listener);
        if (mListeners.isEmpty()) {
            // Stop the scan via cancel.
            mCurrentContext.cancel();
            mCurrentContext = null;
            mHandler.removeCallbacksAndMessages(null);
        }
    }

    private void addAdvertisement(PresentationAdvertisement ad) {
        mElems.add(ad);
        for (ListListener listener : mListeners) {
            listener.notifyItemInserted(mElems.size() - 1);
        }
    }

    private void removeAdvertisement(String id) {
        for (int i = 0; i < mElems.size(); i++) {
            if (id.equals(mElems.get(i).getId())) {
                mElems.remove(i);
                for (ListListener listener : mListeners) {
                    listener.notifyItemRemoved(i);
                }
            }
        }
    }

    private void handleError(Exception e) {
        for (ListListener listener : mListeners) {
            listener.onError(e);
        }
    }

    // Runs in a background thread.
    private void scan() {
        InputChannel<Update> updateChannel = mDiscovery.scan(mCurrentContext, QUERY);
        final VIterable<Update> updates = InputChannels.asIterable(updateChannel);
        for (Update update : updates) {
            if (update instanceof Update.Found) {
                Service descriptor = ((Update.Found) update).getElem().getService();
                Attributes attrs = descriptor.getAttrs();
                String remoteDevice = attrs.get(RpcPresentationDiscovery.DEVICE_ID_ATTRIBUTE);
                if (remoteDevice != null &&
                        remoteDevice.equals(RpcPresentationDiscovery.DEVICE_ID)) {
                    // Self advertisement.
                    continue;
                }
                fetchDetails(descriptor);
            } else {
                String id = ((Update.Lost) update).getElem().getInstanceId();
                mHandler.post(() -> removeAdvertisement(id));
            }
        }
        if (updates.error() != null) {
            mHandler.post(() -> handleError(updates.error()));
        }
    }

    // Runs in a background thread.
    private void fetchDetails(Service descriptor) {
        List<String> addresses = descriptor.getAddrs();
        if (addresses.isEmpty()) {
            Log.e(TAG, "Descriptor " + descriptor.getInstanceId() + " had no addrs.");
            return;
        }
        String name = "/" + addresses.get(0);
        LivePresentationClient client = mClientFactory.make(name);
        VContext rpcContext = mCurrentContext.withCancel();
        PresentationInfo info;
        try {
            info = sync(client.getInfo(rpcContext));
        } catch (VException e) {
            Log.e(TAG, "Failed to fetch presentation info: " + e.getMessage());
            return;
        }
        VDeck vDeck = info.getDeck();
        Deck deck = new DeckImpl(vDeck.getTitle(), vDeck.getThumbnail(), info.getDeckId());
        Person person = new Person(info.getPerson().getBlessing(), info.getPerson().getName());
        final PresentationAdvertisement ad = new PresentationAdvertisement(
                descriptor.getInstanceId(), person, deck, info.getSyncgroupName());
        mHandler.post(() -> addAdvertisement(ad));
    }
}
