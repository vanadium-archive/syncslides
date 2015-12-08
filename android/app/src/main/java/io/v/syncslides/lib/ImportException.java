// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.lib;

/**
 * Thrown when DeckImporter fails to import a deck.
 */
public class ImportException extends Exception {
    public ImportException(Throwable throwable) {
        super(throwable);
    }

    public ImportException(String detailMessage, Throwable throwable) {
        super(detailMessage, throwable);
    }

    public ImportException(String detailMessage) {
        super(detailMessage);
    }
}
