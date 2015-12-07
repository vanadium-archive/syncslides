// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.db;

import android.os.Handler;
import android.os.Looper;

import com.google.common.collect.Lists;
import com.google.common.collect.Sets;

import java.util.List;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.v.syncslides.model.DynamicList;
import io.v.syncslides.model.ListListener;
import io.v.v23.context.CancelableVContext;
import io.v.v23.context.VContext;

/**
 * WatchedList manages an in-memory copy of data that is in syncbase.  The Watcher
 * passed to the WatchedList constructor contains the logic for fetching the
 * actual data from syncbase and sorting it appropriately.  WatchedList keeps
 * track of the data and listeners and notifies the listeners when the data
 * changes.
 */
class WatchedList<E> implements DynamicList<E> {
    private static final String TAG = "WatchedList";

    private final VContext mBaseContext;
    private final Set<ListListener> mListeners;
    private final ExecutorService mExecutor;
    private final Handler mHandler;
    private final Watcher mWatcher;
    private final List<E> mElems;
    private CancelableVContext mCurrentContext;

    WatchedList(VContext context, Watcher watcher) {
        mListeners = Sets.newHashSet();
        mBaseContext = context;
        mExecutor = Executors.newSingleThreadExecutor();
        mHandler = new Handler(Looper.getMainLooper());
        mWatcher = watcher;
        mElems = Lists.newArrayList();
    }

    @Override
    public int getItemCount() {
        return mElems.size();
    }

    @Override
    public E get(int i) {
        return mElems.get(i);
    }

    @Override
    public void addListener(final ListListener listener) {
        if (mListeners.isEmpty()) {
            mListeners.add(listener);
            mCurrentContext = mBaseContext.withCancel();
            mExecutor.submit(new Runnable() {
                @Override
                public void run() {
                    mWatcher.watch(mCurrentContext, new Watcher.Listener<E>() {
                        // TODO(kash): Switch to retrolambda to save on the boilerplate.
                        @Override
                        public void onPut(final E elem) {
                            mHandler.post(new Runnable() {
                                @Override
                                public void run() {
                                    put(elem);
                                }
                            });
                        }

                        @Override
                        public void onDelete(final E elem) {
                            mHandler.post(new Runnable() {
                                @Override
                                public void run() {
                                    delete(elem);
                                }
                            });
                        }

                        @Override
                        public void onError(final Exception e) {
                            mHandler.post(new Runnable() {
                                @Override
                                public void run() {
                                    error(e);
                                }
                            });
                        }
                    });
                }
            });
        }
        mHandler.post(new Runnable() {
            @Override
            public void run() {
                listener.notifyDataSetChanged();
            }
        });
    }

    @Override
    public void removeListener(ListListener listener) {
        mListeners.remove(listener);
        if (mListeners.isEmpty()) {
            // Stop mWatcher via cancel.
            mCurrentContext.cancel();
            mCurrentContext = null;
            mHandler.removeCallbacksAndMessages(null);
        }
    }

    private void put(E elem) {
        int idx = 0;
        for (; idx < mElems.size(); idx++) {
            int comp = mWatcher.compare(mElems.get(idx), elem);
            if (comp == 0) {
                // Existing entry with a change.
                mElems.set(idx, elem);
                for (ListListener listener : mListeners) {
                    listener.notifyItemChanged(idx);
                }
                return;
            } else if (comp > 0) {
                break;
            }
        }
        // New element.
        mElems.add(idx, elem);
        for (ListListener listener : mListeners) {
            listener.notifyItemInserted(idx);
        }

    }

    private void delete(E elem) {
        for (int i = 0; i < mElems.size(); i++) {
            if (mWatcher.compare(mElems.get(i), elem) == 0) {
                mElems.remove(i);
                for (ListListener listener : mListeners) {
                    listener.notifyItemRemoved(i);
                }
            }
        }
    }

    private void error(Exception e) {
        for (ListListener listener : mListeners) {
            listener.onError(e);
        }
    }
}