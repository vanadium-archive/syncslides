// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.model;

/**
 * Provides a list of elements via an API that fits well with RecyclerView.Adapter.
 */
public interface DynamicList<E> {
    /**
     * Returns the number of items in the list.
     */
    int getItemCount();

    /**
     * Returns the ith item in the list.
     */
    E get(int i);

    /**
     * Adds a listener for changes to the list.
     */
    void addListener(ListListener listener);

    /**
     * Stops any subsequent notifications to the given listener.
     */
    void removeListener(ListListener listener);
}
