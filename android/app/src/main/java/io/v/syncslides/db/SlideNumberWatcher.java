// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.db;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.google.common.collect.Sets;

import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.v.impl.google.naming.NamingUtil;
import io.v.syncslides.model.Session;
import io.v.v23.InputChannels;
import io.v.v23.VIterable;
import io.v.v23.context.CancelableVContext;
import io.v.v23.context.VContext;
import io.v.v23.services.watch.ResumeMarker;
import io.v.v23.syncbase.nosql.BatchDatabase;
import io.v.v23.syncbase.nosql.ChangeType;
import io.v.v23.syncbase.nosql.Database;
import io.v.v23.syncbase.nosql.Table;
import io.v.v23.syncbase.nosql.WatchChange;
import io.v.v23.verror.VException;
import io.v.v23.vom.VomUtil;

import static io.v.v23.VFutures.sync;

/**
 * Watches both the local slide number as well as the live presentation's slide number.
 * If the local number is INVALID_LOCAL_SLIDE_NUM, notifies listeners whenever the live
 * presentation's slide number changes.  Otherwise, it notifies listeners whenever the
 * local number changes.
 */
class SlideNumberWatcher {
    private static final String TAG = "SlideNumberWatcher";

    private final VContext mBaseContext;
    private final Database mDb;
    private final Set<Session.SlideNumberListener> mListeners;
    private final ExecutorService mExecutor;
    private final Handler mHandler;
    private final String mSessionId;
    private final String mDeckId;
    private final String mPresentationId;
    private int mLocalSlideNum;
    private VCurrentSlide mCurrentSlide;
    private CancelableVContext mCurrentContext;

    /**
     * If presentationId is non-null, SlideNumberWatcher will watch for changes in addition
     * to watching the session's local slide number.
     */
    SlideNumberWatcher(VContext context, Database db, String sessionId, String deckId,
                       String presentationId) {
        mBaseContext = context;
        mDb = db;
        mSessionId = sessionId;
        mDeckId = deckId;
        mPresentationId = presentationId;
        mListeners = Sets.newHashSet();
        mLocalSlideNum = SyncbaseSession.INVALID_LOCAL_SLIDE_NUM;
        mHandler = new Handler(Looper.getMainLooper());
        mExecutor = Executors.newFixedThreadPool(2);
    }

    void addListener(Session.SlideNumberListener listener) {
        mListeners.add(listener);
        if (mListeners.size() == 1) {
            // First listener.  Start the threads.
            mCurrentContext = mBaseContext.withCancel();
            mExecutor.submit(() -> watchLocalSlideNum());
            mExecutor.submit(() -> watchCurrentSlide());
        }
        listener.onChange(getSlideNum());
    }

    void removeListener(Session.SlideNumberListener listener) {
        mListeners.remove(listener);
        if (mListeners.isEmpty()) {
            // Stop watchers via cancel.
            mCurrentContext.cancel();
            mCurrentContext = null;
            mHandler.removeCallbacksAndMessages(null);
        }
    }

    private void currentSlideChanged(VCurrentSlide slide) {
        mCurrentSlide = slide;
        notifyListeners();
    }

    private void localSlideChanged(int localSlide) {
        mLocalSlideNum = localSlide;
        notifyListeners();
    }

    private void notifyListeners() {
        int slideNum = getSlideNum();
        for (Session.SlideNumberListener listener : mListeners) {
            listener.onChange(slideNum);
        }
    }

    private int getSlideNum() {
        int slideNum = mLocalSlideNum;
        if (slideNum == SyncbaseSession.INVALID_LOCAL_SLIDE_NUM && mCurrentSlide != null) {
            slideNum = mCurrentSlide.getSlideNum();
        }
        return slideNum;
    }

    private void notifyError(Exception e) {
        for (Session.SlideNumberListener listener : mListeners) {
            listener.onError(e);
        }
    }

    // Runs in a background thread.
    private void watchCurrentSlide() {
        try {
            String rowKey = NamingUtil.join(mDeckId, mPresentationId, SyncbaseDB.CURRENT_SLIDE);
            BatchDatabase batch = sync(mDb.beginBatch(mCurrentContext, null));
            Table presentations = batch.getTable(SyncbaseDB.PRESENTATIONS_TABLE);
            if (sync(presentations.getRow(rowKey).exists(mCurrentContext))) {
                final VCurrentSlide slide = (VCurrentSlide) presentations.get(
                        mCurrentContext, rowKey, VCurrentSlide.class);
                mHandler.post(() -> currentSlideChanged(slide));
            }
            ResumeMarker marker = sync(batch.getResumeMarker(mCurrentContext));

            VIterable<WatchChange> changes = InputChannels.asIterable(
                    mDb.watch(mCurrentContext, SyncbaseDB.PRESENTATIONS_TABLE, rowKey, marker));
            for (WatchChange change : changes) {
                String key = change.getRowName();
                Log.i(TAG, "Found CurrentSlide change " + key);
                if (!key.equals(rowKey)) {
                    continue;
                }
                if (change.getChangeType().equals(ChangeType.PUT_CHANGE)) {
                    final VCurrentSlide slide = (VCurrentSlide) VomUtil.decode(
                            change.getVomValue(), VCurrentSlide.class);
                    mHandler.post(() -> currentSlideChanged(slide));
                }
            }
            if (changes.error() != null) {
                throw changes.error();
            }
        } catch (final VException e) {
            mHandler.post(() -> notifyError(e));
        }
    }

    // Runs in a background thread.
    private void watchLocalSlideNum() {
        try {
            BatchDatabase batch = sync(mDb.beginBatch(mCurrentContext, null));
            Table ui = batch.getTable(SyncbaseDB.UI_TABLE);
            final VSession vSession = (VSession) sync(ui.get(
                    mCurrentContext, mSessionId, VSession.class));
            mHandler.post(() -> localSlideChanged(vSession.getLocalSlide()));
            ResumeMarker marker = sync(batch.getResumeMarker(mCurrentContext));
            VIterable<WatchChange> changes =
                    InputChannels.asIterable(mDb.watch(
                            mCurrentContext, SyncbaseDB.UI_TABLE, mSessionId, marker));
            for (WatchChange change : changes) {
                String key = change.getRowName();
                Log.i(TAG, "Found local slide change " + key);
                if (!key.equals(mSessionId)) {
                    continue;
                }
                if (change.getChangeType().equals(ChangeType.PUT_CHANGE)) {
                    final VSession vSession1 = (VSession) VomUtil.decode(
                            change.getVomValue(), VSession.class);
                    mHandler.post(() -> localSlideChanged(vSession1.getLocalSlide()));
                }
            }
            if (changes.error() != null) {
                throw changes.error();
            }
         } catch (final VException e) {
            mHandler.post(() -> notifyError(e));
        }
    }
}
