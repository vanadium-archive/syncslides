// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.model;

/**
 * Contains sufficient details of a live presentation such that a potential audience
 * member could choose to join it.
 */
public class PresentationAdvertisement {
    private final String mId;
    private final Person mPresenter;
    private final Deck mDeck;
    private final String mSyncgroupName;

    public PresentationAdvertisement(String id, Person presenter, Deck deck, String syncgroupName) {
        mId = id;
        mPresenter = presenter;
        mDeck = deck;
        mSyncgroupName = syncgroupName;
    }

    /**
     * Returns the unique ID for this presentation.
     */
    public String getId() {
        return mId;
    }

    /**
     * Returns the person who is presenting.
     */
    public Person getPresenter() {
        return mPresenter;
    }

    /**
     * Returns the deck being presented.
     */
    public Deck getDeck() {
        return mDeck;
    }

    /**
     * Returns the syncgroup name for this presentation.
     */
    public String getSyncgroupName() {
        return mSyncgroupName;
    }

    /**
     * Detects equality with the id passed to the constructor.
     */
    @Override
    public boolean equals(Object o) {
        if (o instanceof PresentationAdvertisement) {
            PresentationAdvertisement other = (PresentationAdvertisement) o;
            return mId.equals(other.mId);
        }
        return false;
    }
}
