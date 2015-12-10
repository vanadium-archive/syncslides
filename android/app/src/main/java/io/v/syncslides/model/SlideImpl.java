// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.model;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

/**
 * Slide implementation that decodes byte arrays into Bitmaps only when
 * a getter is called, to conserve memory.
 */
public class SlideImpl implements Slide {
    private String mId;
    private final byte[] mThumbnail;
    private final byte[] mImage;
    private String mNotes;

    public SlideImpl(String id, byte[] thumbnail, byte[] image, String notes) {
        mId = id;
        mThumbnail = thumbnail;
        mImage = image;
        mNotes = notes;
    }

    @Override
    public String getId() {
        return mId;
    }
    @Override
    public Bitmap getThumb() {
        return BitmapFactory.decodeByteArray(mThumbnail, 0 /* offset */, mThumbnail.length);
    }
    @Override
    public byte[] getThumbData() {
        return mThumbnail;
    }
    @Override
    public Bitmap getImage() {
        return BitmapFactory.decodeByteArray(mImage, 0 /* offset */, mImage.length);
    }
    @Override
    public byte[] getImageData() {
        return mImage;
    }
    @Override
    public String getNotes() {
        return mNotes;
    }
}
