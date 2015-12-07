// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.db;

import android.util.Log;

import java.util.Comparator;
import java.util.List;

import io.v.impl.google.naming.NamingUtil;
import io.v.syncslides.model.Deck;
import io.v.syncslides.model.DeckImpl;
import io.v.v23.VIterable;
import io.v.v23.context.VContext;
import io.v.v23.services.watch.ResumeMarker;
import io.v.v23.syncbase.nosql.BatchDatabase;
import io.v.v23.syncbase.nosql.ChangeType;
import io.v.v23.syncbase.nosql.Database;
import io.v.v23.syncbase.nosql.DatabaseCore;
import io.v.v23.syncbase.nosql.WatchChange;
import io.v.v23.vdl.VdlAny;
import io.v.v23.verror.VException;
import io.v.v23.vom.VomUtil;
import static io.v.v23.VFutures.sync;

/**
 * Watches all of the decks in syncbase for changes.  Decks are sorted by their ID (which
 * is a random number).  TODO(kash): Sort by something more useful.
 */
class DeckWatcher implements Watcher<Deck> {

    private static final String TAG = "DeckWatcher";
    private final Database mDB;

    DeckWatcher(Database db) {
        mDB = db;
    }

    public void watch(VContext context, Listener<Deck> listener) {
        try {
            BatchDatabase batch = sync(mDB.beginBatch(context, null));
            ResumeMarker resumeMarker = sync(batch.getResumeMarker(context));
            DatabaseCore.QueryResults results = sync(batch.exec(context,
                    "SELECT k, v FROM Decks WHERE Type(v) like \"%VDeck\""));
            for (List<VdlAny> row : results) {
                if (row.size() != 2) {
                    throw new VException("Wrong number of columns: " + row.size());
                }
                String key = (String) row.get(0).getElem();
                Log.i(TAG, "Fetched deck " + key);
                VDeck vDeck = (VDeck) row.get(1).getElem();
                listener.onPut(new DeckImpl(vDeck.getTitle(), vDeck.getThumbnail(), key));
            }
            if (results.error() != null) {
                throw results.error();
            }

            VIterable<WatchChange> changes = sync(mDB.watch(
                    context, SyncbaseDB.DECKS_TABLE, "", resumeMarker));
            for (WatchChange change : changes) {
                final String key = change.getRowName();
                // Ignore slide changes.
                if (NamingUtil.split(key).size() != 1) {
                    continue;
                }
                Log.d(TAG, "Processing change to deck: " + key);
                if (change.getChangeType().equals(ChangeType.PUT_CHANGE)) {
                    // New deck or change to an existing deck.
                    VDeck vDeck = null;
                    try {
                        vDeck = (VDeck) VomUtil.decode(change.getVomValue(), VDeck.class);
                    } catch (VException e) {
                        Log.e(TAG, "Couldn't decode deck: " + e.toString());
                        continue;
                    }
                    final Deck deck = new DeckImpl(
                            vDeck.getTitle(), vDeck.getThumbnail(), key);
                    listener.onPut(deck);
                } else {  // ChangeType.DELETE_CHANGE
                    listener.onDelete(new DeckImpl(null, null, key));
                }
            }
            if (changes.error() != null) {
                throw changes.error();
            }
            Log.d(TAG, "Deck change thread exiting");
        } catch (Exception e) {
            listener.onError(e);
        }
    }

    public int compare(Deck lhs, Deck rhs) {
        return lhs.getId().compareTo(rhs.getId());
    }
}
