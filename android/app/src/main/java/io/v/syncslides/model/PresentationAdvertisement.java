// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.model;

/**
 * Contains sufficient details of a live presentation such that a potential audience
 * member could choose to join it.
 */
public class PresentationAdvertisement {
    Person mPresenter;
    Deck mDeck;
    String mSyncgroupName;

    public PresentationAdvertisement(Person presenter, Deck deck, String syncgroupName) {
        mPresenter = presenter;
        mDeck = deck;
        mSyncgroupName = syncgroupName;
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
}
