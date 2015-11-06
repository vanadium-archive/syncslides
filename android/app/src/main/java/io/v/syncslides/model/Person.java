// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.model;

/**
 * Represents either an audience member or the presenter.
 */
public class Person {
    String mBlessing;
    String mName;

    /**
     * @param blessing the Vanadium blessing for this user
     * @param name the human full name
     */
    public Person(String blessing, String name) {
        mBlessing = blessing;
        mName = name;
    }

    /**
     * Returns the blessing for this user.
     */
    public String getBlessing() {
        return mBlessing;
    }

    /**
     * Returns the human full name.
     */
    public String getName() {
        return mName;
    }
}