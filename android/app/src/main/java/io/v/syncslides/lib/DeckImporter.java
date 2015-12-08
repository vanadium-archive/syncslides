// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.lib;

import android.content.ContentResolver;
import android.support.v4.provider.DocumentFile;

import com.google.common.base.Charsets;
import com.google.common.io.ByteStreams;
import com.google.common.util.concurrent.ListenableFuture;
import com.google.common.util.concurrent.ListeningExecutorService;
import com.google.common.util.concurrent.MoreExecutors;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.Executors;

import io.v.syncslides.db.DB;
import io.v.syncslides.model.Deck;
import io.v.syncslides.model.DeckImpl;
import io.v.syncslides.model.Slide;
import io.v.syncslides.model.SlideImpl;
import io.v.v23.verror.VException;

import static io.v.v23.VFutures.sync;

/**
 * Imports a slide deck from the given (local) folder directly into the DB.
 *
 * The folder must contain a JSON metadata file 'deck.json' with the following format:
 * {
 *     "Title" : "<title>",
 *     "Thumb" : "<filename>,
 *     "Slides" : [
 *          {
 *              "Thumb" : "<thumb_filename1>",
 *              "Image" : "<image_filename1>",
 *              "Note" : "<note1>"
 *          },
 *          {
 *              "Thumb" : "<thumb_filename2>",
 *              "Image" : "<image_filename2>",
 *              "Note" : "<note2>"
 *          },
 *
 *          ...
 *     ]
 * }
 *
 * All the filenames must be local to the given folder.
 */
public class DeckImporter {

    private static final String DECK_JSON = "deck.json";
    private static final String TITLE = "Title";
    private static final String THUMB = "Thumb";
    private static final String SLIDES = "Slides";
    private static final String IMAGE = "Image";
    private static final String NOTE = "Note";

    private final ListeningExecutorService mExecutorService;
    private ContentResolver mContentResolver;
    private DB mDB;

    public DeckImporter(ContentResolver contentResolver, DB db) {
        mExecutorService = MoreExecutors.listeningDecorator(Executors.newSingleThreadExecutor());
        mContentResolver = contentResolver;
        mDB = db;
    }

    public ListenableFuture<Void> importDeck(final DocumentFile dir) {
        return mExecutorService.submit(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                return importDeckImpl(dir);
            }
        });
    }

    private Void importDeckImpl(DocumentFile dir) throws ImportException {
        if (!dir.isDirectory()) {
            throw new ImportException("Must import from a directory, got: " + dir);
        }
        // Read the deck metadata file.
        DocumentFile metadataFile = dir.findFile(DECK_JSON);
        if (metadataFile == null) {
            throw new ImportException("Couldn't find deck metadata file 'deck.json'");
        }
        JSONObject metadata = null;
        try {
            String data = new String(ByteStreams.toByteArray(
                    mContentResolver.openInputStream(metadataFile.getUri())),
                    Charsets.UTF_8);
            metadata = new JSONObject(data);
        } catch (FileNotFoundException e) {
            throw new ImportException("Couldn't open deck metadata file", e);
        } catch (IOException e) {
            throw new ImportException("Couldn't read data from deck metadata file", e);
        } catch (JSONException e) {
            throw new ImportException("Couldn't parse deck metadata", e);
        }

        try {
            String id = UUID.randomUUID().toString();
            String title = metadata.getString(TITLE);
            byte[] thumbData = readImage(dir, metadata.getString(THUMB));
            Deck deck = new DeckImpl(title, thumbData, id);
            Slide[] slides = readSlides(dir, metadata);
            sync(mDB.importDeck(deck, slides));
        } catch (JSONException e) {
            throw new ImportException("Invalid format for deck metadata", e);
        } catch (IOException e) {
            throw new ImportException("Error interpreting deck metadata", e);
        } catch (VException e) {
            throw new ImportException("Error importing deck", e);
        }
        return null;
    }

    // TODO(kash): Lazily read the slide images so we don't need to have them all
    // in memory simultaneously.
    private Slide[] readSlides(DocumentFile dir, JSONObject metadata)
            throws JSONException, IOException {
        if (!metadata.has(SLIDES)) {
            return new Slide[0];
        }
        JSONArray slides = metadata.getJSONArray(SLIDES);
        Slide[] ret = new Slide[slides.length()];
        for (int i = 0; i < slides.length(); ++i) {
            JSONObject slide = slides.getJSONObject(i);
            byte[] thumbData = readImage(dir, slide.getString(THUMB));
            byte[] imageData = thumbData;
            if (slide.has(IMAGE)) {
                imageData = readImage(dir, slide.getString(IMAGE));
            }
            String note = slide.getString(NOTE);
            ret[i] = new SlideImpl(thumbData, imageData, note);
        }
        return ret;
    }

    private byte[] readImage(DocumentFile dir, String fileName) throws IOException {
        DocumentFile file = dir.findFile(fileName);
        if (file == null) {
            throw new FileNotFoundException("Image file doesn't exist: " + fileName);
        }
        return ByteStreams.toByteArray(mContentResolver.openInputStream(file.getUri()));
    }
}
