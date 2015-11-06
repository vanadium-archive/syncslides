// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.discovery;

import io.v.syncslides.model.DynamicList;
import io.v.syncslides.model.PresentationAdvertisement;
import io.v.v23.context.VContext;

/**
 * Handles advertising and scanning for live presentations.
 */
public interface PresentationDiscovery {
    /**
     * Finds all live presentations.  The returned list will be continually
     * updated as new presentations start and old presentations end.
     */
    DynamicList<PresentationAdvertisement> scan();

    /**
     * Starts advertising a presentation.
     * @param vContext context for the advertisement.  Client should cancel the context
     *                 to stop advertising.
     * @param advertisement details of the presentation.
     */
    void advertise(VContext vContext, PresentationAdvertisement advertisement);
}
