// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.db;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

import io.v.syncslides.model.Slide;

/**
 * DBSlide is backed by our database-specific datastructures.  It lazily fetches the full-size
 * image from syncbase.
 */
class DBSlide implements Slide {

    private final String mId;
    private final VSlide mVSlide;
    private final String mNotes;

    DBSlide(String id, VSlide vSlide, String notes) {
        mId = id;
        mVSlide = vSlide;
        mNotes = notes;
    }

    @Override
    public String getId() {
        return mId;
    }

    @Override
    public Bitmap getThumb() {
        byte[] thumbnail = mVSlide.getThumbnail();
        return BitmapFactory.decodeByteArray(thumbnail, 0 /* offset */, thumbnail.length);
    }

    @Override
    public byte[] getThumbData() {
        return mVSlide.getThumbnail();
    }

    @Override
    public Bitmap getImage() {
        // TODO(kash): I think I want to change this API to return a future so the UI is
        // not blocked on loading the image.
        throw new RuntimeException("Implement me");
    }

    @Override
    public byte[] getImageData() {
        // TODO(kash): I think I want to change this API to return a future so the UI is
        // not blocked on loading the image.
        throw new RuntimeException("Implement me");
    }

    @Override
    public String getNotes() {
        return mNotes;
    }
}
