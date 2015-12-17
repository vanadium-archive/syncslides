// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.model;

import io.v.v23.verror.VException;

/**
 * A Session represents the UI state for one presentation.
 */
public interface Session {
    String getId();

    String getDeckId();

    String getPresentationId();

    /**
     * Store the user's desire to view the given slide.  This will trigger a notification to
     * any SlideNumberListeners.
     *
     * @param slideNum the number of the slide
     */
    void setLocalSlideNum(int slideNum) throws VException;

    interface SlideNumberListener {
        /**
         * Called whenever the UI should display a different slide.  If the user is following
         * a live presentation, this will be called when the driver of the presentation changes
         * the current slide.  If the user is browsing a presentation on his own, this will
         * be triggered by calls to setLocalSlideNum().
         */
        void onChange(int slideNum);
        /**
         * Called whenever there is an error.  The listener should unregister and re-register
         * itself if it wants to continue.
         */
        void onError(Exception e);
    }

    /**
     * Adds a listener for changes to the to-be-displayed slide.
     *
     * @param listener notified of changes
     */
    void addSlideNumberListener(SlideNumberListener listener);

    /**
     * Removes a listener that was previously passed to addSlideNumberListener().
     *
     * @param listener previously passed to addSlideNumberListener().
     */
    void removeSlideNumberListener(SlideNumberListener listener);

    /**
     * Returns a dynamically updating list of slides in the deck.
     */
    DynamicList<Slide> getSlides();

}
