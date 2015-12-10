// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.db;

import io.v.syncslides.model.Session;

/**
 * SyncbaseSession gets its session state from Syncbase.
 */
class SyncbaseSession implements Session {
    private final VSession mVSession;

    SyncbaseSession(VSession vSession) {
        mVSession = vSession;
    }

    @Override
    public String getDeckId() {
        return mVSession.getDeckId();
    }

    @Override
    public String getPresentationId() {
        return mVSession.getPresentationId();
    }
}
