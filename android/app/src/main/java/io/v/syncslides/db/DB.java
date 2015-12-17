// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.db;

import android.content.Context;

import com.google.common.util.concurrent.ListenableFuture;

import io.v.syncslides.InitException;
import io.v.syncslides.model.Deck;
import io.v.syncslides.model.DynamicList;
import io.v.syncslides.model.Session;
import io.v.syncslides.model.Slide;
import io.v.v23.verror.VException;

/**
 * Provides high-level methods for getting and setting the state of SyncSlides.
 * It is an interface instead of a concrete class to make testing easier.
 */
public interface DB {
    class Singleton {
        private static volatile DB instance;

        public static DB get() {
            DB result = instance;
            if (instance == null) {
                synchronized (Singleton.class) {
                    result = instance;
                    if (result == null) {
                        instance = result = new SyncbaseDB();
                    }
                }
            }
            return result;
        }
    }

    /**
     * Perform initialization steps.
     */
    void init(Context context) throws InitException;

    /**
     * Creates a new session in the database for a local viewing of a deck.  The user
     * can later turn this into a live presentation.
     *
     * @param deckId the ID of the deck that the user is viewing
     * @return the unique ID for the session to later be passed to {@link #getSession(string)}.
     */
    String createSession(String deckId) throws VException;

    /**
     * Returns the Session for the given ID.  This method is synchronous because
     * it fetches a small amount of data and therefore it can complete quickly.
     * Additionally, very little UI can be rendered without the information
     * contained in the Session.
     */
    Session getSession(String sessionId) throws VException;

    /**
     * Returns a dynamically updating list of decks that are visible to the user.
     */
    DynamicList<Deck> getDecks();

    /**
     * Asynchronously imports the slide deck along with its slides.
     *
     * @param deck     deck to import
     * @param slides   slides belonging to the above deck
     * @return allows the client to detect when the import is complete
     */
    ListenableFuture<Void> importDeck(Deck deck, Slide[] slides);

}
