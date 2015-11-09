// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides;

/**
 * Thrown when initialization fails.
 */
public class InitException extends Exception {
    public InitException(Throwable throwable) {
        super(throwable);
    }

    public InitException(String detailMessage, Throwable throwable) {
        super(detailMessage, throwable);
    }
}
