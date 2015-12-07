// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.model;

/**
 * Callbacks for list changes.
 */
public interface ListListener {
    void notifyDataSetChanged();
    void notifyItemChanged(int position);
    void notifyItemInserted(int position);
    void notifyItemRemoved(int position);
    void onError(Exception e);
}
