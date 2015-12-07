// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.db;

import java.util.Comparator;

import io.v.v23.context.VContext;

/**
 * Implementations of Watcher work closely with @see io.v.syncslides.db.WatchedList to
 * watch a set of data in syncbase for changes.  In addition to watching for changes,
 * a Watcher also knows how to sort the data appropriately for display in a UI.
 */
public interface Watcher<E> extends Comparator<E> {
    /**
     * Fetches the initial data set from Syncbase and then watches it for subsequent changes.
     * Both the initial data set and changes are passed to {@code listener}.
     *
     * @param context to be used for communications with Syncbase
     * @param listener receives notifications for the initial data and for changes
     */
    void watch(VContext context, Listener<E> listener);

    /**
     * Receives notifications of type E for the Watcher's data set.  These
     * notifications will run in an arbitrary thread.
     */
    interface Listener<E> {
        /**
         * Notifies that {@code elem} was inserted or changed.
         */
        void onPut(E elem);

        /**
         * Notifies that {@code elem} was deleted.
         */
        void onDelete(E elem);

        /**
         * Notifies that there was an error and the Watcher is no longer running.
         */
        void onError(Exception e);
    }
}
