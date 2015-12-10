// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.db;

import io.v.syncslides.model.DynamicList;
import io.v.syncslides.model.Slide;

/**
 * A Presentation acts as a bridge between the UI and the database for all of the state related
 * to a presentation.
 */
public interface Presentation {

    /**
     * Returns a dynamically updating list of slides in the deck.
     */
    DynamicList<Slide> getSlides();
}
