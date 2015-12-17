// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.db;

import org.joda.time.Duration;

import io.v.syncslides.model.DynamicList;
import io.v.syncslides.model.Session;
import io.v.syncslides.model.Slide;
import io.v.v23.context.CancelableVContext;
import io.v.v23.context.VContext;
import io.v.v23.syncbase.nosql.Database;
import io.v.v23.syncbase.nosql.Table;
import io.v.v23.verror.VException;

import static io.v.v23.VFutures.sync;

/**
 * SyncbaseSession gets its session state from Syncbase.
 */
class SyncbaseSession implements Session {
    /**
     * The user wants to follow a live presentation or hasn't yet chosen a slide to view.
     */
    static final int INVALID_LOCAL_SLIDE_NUM = -1;
    private static final long UNINITIALIZED_TIME = 0;

    private final VContext mVContext;
    private final Database mDb;
    private final String mId;
    private final VSession mVSession;
    private final SlideNumberWatcher mSlideNumberWatcher;
    private final DynamicList<Slide> mSlides;

    SyncbaseSession(VContext vContext, Database db, String id, String deckId) {
        this(vContext, db, id,
                new VSession(deckId, null, INVALID_LOCAL_SLIDE_NUM, UNINITIALIZED_TIME));
    }

    SyncbaseSession(VContext vContext, Database db, String id, VSession vSession) {
        mVContext = vContext;
        mDb = db;
        mId = id;
        mVSession = vSession;
        mSlideNumberWatcher = new SlideNumberWatcher(mVContext, mDb, id, mVSession.getDeckId(),
                mVSession.getPresentationId());
        mSlides = new WatchedList<>(mVContext, new SlideWatcher(mDb, mVSession.getDeckId()));
    }

    @Override
    public String getId() {
        return mId;
    }

    @Override
    public String getDeckId() {
        return mVSession.getDeckId();
    }

    @Override
    public String getPresentationId() {
        return mVSession.getPresentationId();
    }

    @Override
    public void setLocalSlideNum(int slideNum) throws VException {
        // TODO(kash): if the user is driving, this should update the presentation state instead.
        mVSession.setLocalSlide(slideNum);
        save();
    }

    @Override
    public void addSlideNumberListener(SlideNumberListener listener) {
        mSlideNumberWatcher.addListener(listener);
    }

    @Override
    public void removeSlideNumberListener(SlideNumberListener listener) {
        mSlideNumberWatcher.removeListener(listener);
    }

    @Override
    public DynamicList<Slide> getSlides() {
        return mSlides;
    }

    /**
     * Persists the VSession to the UI_TABLE.
     *
     * @throws VException when the Syncbase put() fails
     */
    void save() throws VException {
        mVSession.setLastTouched(System.currentTimeMillis());
        Table ui = mDb.getTable(SyncbaseDB.UI_TABLE);
        CancelableVContext context = mVContext.withTimeout(Duration.millis(5000));
        sync(ui.put(context, mId, mVSession, VSession.class));
    }
}
