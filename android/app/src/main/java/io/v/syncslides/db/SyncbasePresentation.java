// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.db;

import io.v.syncslides.model.DynamicList;
import io.v.syncslides.model.Session;
import io.v.syncslides.model.Slide;
import io.v.v23.context.VContext;
import io.v.v23.syncbase.nosql.Database;

class SyncbasePresentation implements Presentation {
    private final VContext mVContext;
    private final Database mDb;
    private final Session mSession;

    public SyncbasePresentation(VContext vContext, Database db, Session session) {
        mVContext = vContext;
        mDb = db;
        mSession = session;
    }

    @Override
    public DynamicList<Slide> getSlides() {
        // TODO(kash): Cache this list so it survives a phone rotation.
        // We'll need a corresponding method to clear the cache when this
        // Presentation is no longer needed.
        return new WatchedList<>(mVContext, new SlideWatcher(mDb, mSession.getDeckId()));
    }
}
