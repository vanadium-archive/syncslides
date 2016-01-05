// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.db;

import android.util.Log;

import java.util.List;

import io.v.impl.google.naming.NamingUtil;
import io.v.syncslides.model.Slide;
import io.v.syncslides.model.SlideImpl;
import io.v.v23.VIterable;
import io.v.v23.context.VContext;
import io.v.v23.services.watch.ResumeMarker;
import io.v.v23.syncbase.nosql.BatchDatabase;
import io.v.v23.syncbase.nosql.ChangeType;
import io.v.v23.syncbase.nosql.Database;
import io.v.v23.syncbase.nosql.DatabaseCore;
import io.v.v23.syncbase.nosql.Table;
import io.v.v23.syncbase.nosql.WatchChange;
import io.v.v23.vdl.VdlAny;
import io.v.v23.verror.NoExistException;
import io.v.v23.verror.VException;
import io.v.v23.vom.VomUtil;

import static io.v.v23.VFutures.sync;

/**
 * Watches the slides in a single deck for changes.  Slides are sorted by their key.
 */
class SlideWatcher implements Watcher<Slide> {

    private static final String TAG = "SlideWatcher";
    private final Database mDb;
    private final String mDeckId;

    SlideWatcher(Database db, String deckId) {
        mDb = db;
        mDeckId = deckId;
    }

    @Override
    public void watch(final VContext context, final Listener<Slide> listener) {
        try {
            BatchDatabase batch = sync(mDb.beginBatch(context, null));
            final ResumeMarker watchMarker = sync(batch.getResumeMarker(context));
            fetchInitialState(context, listener, batch);
            // Need to watch two tables, but the API allows watching only one
            // table at a time.  Start another thread for watching the notes.
            new Thread(() -> {
                try {
                    watchNoteChanges(context, listener, watchMarker);
                } catch (VException e) {
                    listener.onError(e);
                }
            }).start();
            watchSlideChanges(context, listener, watchMarker);
        } catch (VException e) {
            listener.onError(e);
        }
    }

    @Override
    public int compare(Slide lhs, Slide rhs) {
        return lhs.getId().compareTo(rhs.getId());
    }

    private void fetchInitialState(VContext context, Listener<Slide> listener,
                                   BatchDatabase batch) throws VException {
        Table notesTable = batch.getTable(SyncbaseDB.NOTES_TABLE);
        String query = "SELECT k, v FROM Decks WHERE Type(v) LIKE \"%VSlide\" " +
                "AND k LIKE \"" + NamingUtil.join(mDeckId, "slides") + "%\"";
        DatabaseCore.QueryResults results = sync(batch.exec(context, query));
        for (List<VdlAny> row : results) {
            if (row.size() != 2) {
                throw new VException("Wrong number of columns: " + row.size());
            }
            final String key = (String) row.get(0).getElem();
            Log.i(TAG, "Fetched slide " + key);
            VSlide slide = (VSlide) row.get(1).getElem();
            String notes = notesForSlide(context, notesTable, key);
            Slide newSlide = new DBSlide(key, slide, notes);
            listener.onPut(newSlide);
        }
    }

    private void watchSlideChanges(VContext context, Listener<Slide> listener,
                                   ResumeMarker watchMarker) throws VException {
        Table notesTable = mDb.getTable(SyncbaseDB.NOTES_TABLE);
        VIterable<WatchChange> changes =
                sync(mDb.watch(context, SyncbaseDB.DECKS_TABLE, mDeckId, watchMarker));
        for (WatchChange change : changes) {
            String key = change.getRowName();
            if (isDeckKey(key)) {
                Log.d(TAG, "Ignoring deck change: " + key);
                continue;
            }
            if (change.getChangeType().equals(ChangeType.PUT_CHANGE)) {
                // New slide or change to an existing slide.
                VSlide vSlide = null;
                try {
                    vSlide = (VSlide) VomUtil.decode(change.getVomValue(), VSlide.class);
                } catch (VException e) {
                    Log.e(TAG, "Couldn't decode slide: " + e.toString());
                    continue; // Just skip it.
                }
                String notes = notesForSlide(context, notesTable, key);
                Slide newSlide = new DBSlide(key, vSlide, notes);
                listener.onPut(newSlide);
            } else { // ChangeType.DELETE_CHANGE
                listener.onDelete(new SlideImpl(key, null, null, null));
            }
        }
        if (changes.error() != null) {
            throw changes.error();
        }
    }

    private void watchNoteChanges(VContext context, Listener<Slide> listener,
                                  ResumeMarker watchMarker) throws VException {
        Table decksTable = mDb.getTable(SyncbaseDB.DECKS_TABLE);
        VIterable<WatchChange> changes =
                sync(mDb.watch(context, SyncbaseDB.NOTES_TABLE, mDeckId, watchMarker));
        for (WatchChange change : changes) {
            String key = change.getRowName();
            if (!SyncbaseDB.isSlideKey(key)) {
                continue;
            }
            VSlide vSlide = fetchVSlide(context, decksTable, key);
            if (vSlide == null) {
                // If the VSlide was deleted, the other watcher will handle the notification.
                continue;
            }
            String notes = null;
            if (change.getChangeType().equals(ChangeType.PUT_CHANGE)) {
                VNote vNote = null;
                try {
                    vNote = (VNote) VomUtil.decode(change.getVomValue(), VNote.class);
                } catch (VException e) {
                    Log.e(TAG, "Couldn't decode notes: " + e.toString());
                    continue; // Just skip it.
                }
                notes = vNote.getText();
            } else { // ChangeType.DELETE_CHANGE
                notes = "";
            }
            Slide newSlide = new DBSlide(key, vSlide, notes);
            listener.onPut(newSlide);
        }
        if (changes.error() != null) {
            throw changes.error();
        }
    }

    /**
     * Returns true if {@code key} looks like a VDeck and not a VSlide.
     */
    private boolean isDeckKey(String key) {
        return NamingUtil.split(key).size() <= 1;
    }

    private static String notesForSlide(VContext context, Table notesTable, String key)
            throws VException {
        try {
            VNote note = (VNote) sync(notesTable.get(context, key, VNote.class));
            return note.getText();
        } catch (NoExistException e) {
            // It is ok for the notes to not exist for a slide.
            return "";
        }
    }

    private static VSlide fetchVSlide(VContext context, Table decksTable, String key)
            throws VException {
        try {
            return (VSlide) sync(decksTable.get(context, key, VSlide.class));
        } catch (NoExistException e) {
            return null;
        }
    }
}
