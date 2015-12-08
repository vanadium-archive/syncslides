// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.DocumentsContract;
import android.support.design.widget.FloatingActionButton;
import android.support.v4.app.Fragment;
import android.support.v4.provider.DocumentFile;
import android.support.v7.widget.GridLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver;
import android.widget.Toast;

import com.google.common.base.Charsets;
import com.google.common.io.ByteStreams;
import com.google.common.util.concurrent.FutureCallback;
import com.google.common.util.concurrent.Futures;
import com.google.common.util.concurrent.ListenableFuture;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.UUID;

import io.v.syncslides.db.DB;
import io.v.syncslides.lib.DeckImporter;
import io.v.syncslides.model.Deck;
import io.v.syncslides.model.DeckImpl;
import io.v.syncslides.model.Slide;
import io.v.syncslides.model.SlideImpl;

/**
 * This fragment contains the list of decks as well as the FAB to create a new
 * deck.
 */
public class DeckChooserFragment extends Fragment {
    /**
     * The fragment argument representing the section number for this fragment.
     */
    private static final String ARG_SECTION_NUMBER = "section_number";
    private static final String TAG = "DeckChooserFragment";
    private static final int REQUEST_CODE_IMPORT_DECK = 1000;
    private RecyclerView mRecyclerView;
    private GridLayoutManager mLayoutManager;
    private DeckListAdapter mAdapter;

    /**
     * Returns a new instance of this fragment for the given section number.
     */
    public static DeckChooserFragment newInstance(int sectionNumber) {
        DeckChooserFragment fragment = new DeckChooserFragment();
        Bundle args = new Bundle();
        args.putInt(ARG_SECTION_NUMBER, sectionNumber);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
        View rootView = inflater.inflate(R.layout.fragment_deck_chooser, container, false);
        FloatingActionButton fab = (FloatingActionButton) rootView.findViewById(R.id.new_deck_fab);
        fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                onImportDeck();
            }
        });
        mRecyclerView = (RecyclerView) rootView.findViewById(R.id.deck_grid);
        // The cards for the decks are always the same size.
        mRecyclerView.setHasFixedSize(true);

        // Statically set the span count (i.e. number of columns) for now...  See below.
        mLayoutManager = new GridLayoutManager(getContext(), 2);
        mRecyclerView.setLayoutManager(mLayoutManager);
        // Dynamically set the span based on the screen width.  Cribbed from
        // http://stackoverflow.com/questions/26666143/recyclerview-gridlayoutmanager-how-to-auto-detect-span-count
        mRecyclerView.getViewTreeObserver().addOnGlobalLayoutListener(
                new ViewTreeObserver.OnGlobalLayoutListener() {
                    @Override
                    public void onGlobalLayout() {
                        mRecyclerView.getViewTreeObserver().removeOnGlobalLayoutListener(this);
                        int viewWidth = mRecyclerView.getMeasuredWidth();
                        float cardViewWidth = getActivity().getResources().getDimension(
                                R.dimen.deck_card_width);
                        int newSpanCount = (int) Math.floor(viewWidth / cardViewWidth);
                        mLayoutManager.setSpanCount(newSpanCount);
                        mLayoutManager.requestLayout();
                    }
                });
        mAdapter = new DeckListAdapter(DB.Singleton.get());

        return rootView;
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        switch (requestCode) {
            case REQUEST_CODE_IMPORT_DECK:
                if (resultCode != Activity.RESULT_OK) {
                    String errorStr = data != null && data.hasExtra(DocumentsContract.EXTRA_ERROR)
                            ? data.getStringExtra(DocumentsContract.EXTRA_ERROR)
                            : "";
                    toast("Error selecting deck to import " + errorStr);
                    break;
                }
                Uri uri = data.getData();
                DeckImporter importer = new DeckImporter(
                        getActivity().getContentResolver(), DB.Singleton.get());
                ListenableFuture<Void> future = importer.importDeck(
                        DocumentFile.fromTreeUri(getContext(), uri));
                Futures.addCallback(future, new FutureCallback<Void>() {
                    @Override
                    public void onSuccess(Void result) {
                        toast("Import complete");
                    }

                    @Override
                    public void onFailure(Throwable t) {
                        toast("Import failed: " + t.getMessage());
                    }
                });
                break;
        }
    }

    @Override
    public void onAttach(Activity activity) {
        super.onAttach(activity);
        ((DeckChooserActivity) activity).onSectionAttached(
                getArguments().getInt(ARG_SECTION_NUMBER));
    }

    @Override
    public void onStart() {
        super.onStart();
        Log.i(TAG, "Starting");
        mAdapter.start();
        mRecyclerView.setAdapter(mAdapter);
    }

    @Override
    public void onStop() {
        super.onStop();
        Log.i(TAG, "Stopping");
        mAdapter.stop();
        mRecyclerView.setAdapter(null);
    }

    /**
     * Import a deck so it shows up in the list of all decks.
     */
    private void onImportDeck() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        startActivityForResult(intent, REQUEST_CODE_IMPORT_DECK);
    }

    /**
     * Creates a toast in the main looper.  Useful since lots of this class runs in a
     * background thread.
     */
    private void toast(final String msg) {
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                Toast.makeText(getActivity(), msg, Toast.LENGTH_LONG).show();
            }
        });
    }
}
