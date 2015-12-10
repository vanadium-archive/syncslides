// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides;

import android.os.Bundle;
import android.support.design.widget.FloatingActionButton;
import android.support.v4.app.Fragment;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import io.v.syncslides.db.DB;
import io.v.syncslides.model.Session;
import io.v.v23.verror.VException;

/**
 * Displays the set of slides in a deck as a scrolling list.
 */
public class SlideListFragment extends Fragment {

    private static final String SESSION_ID_KEY = "session_id_key";
    private static final String TAG = "SlideListFragment";

    private Session mSession;
    private RecyclerView mRecyclerView;
    private LinearLayoutManager mLayoutManager;
    private SlideListAdapter mAdapter;

    /**
     * Returns a new instance of this fragment for the given deck.
     */
    public static SlideListFragment newInstance(String sessionId) {
        SlideListFragment fragment = new SlideListFragment();
        Bundle args = new Bundle();
        args.putString(SESSION_ID_KEY, sessionId);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
        // See comment at the top of fragment_slide_list.xml.
        ((PresentationActivity) getActivity()).setUiImmersive(false);
        // Inflate the layout for this fragment
        View rootView = inflater.inflate(R.layout.fragment_slide_list, container, false);

        Bundle bundle = savedInstanceState;
        if (bundle == null) {
            bundle = getArguments();
        }
        String sessionId = bundle.getString(SESSION_ID_KEY);
        try {
            mSession = DB.Singleton.get().getSession(sessionId);
        } catch (VException e) {
            handleError("Failed to fetch Session", e);
            getActivity().finish();
        }

        // If there is not already a presentation for this session,
        // make the FAB visible so that clicking it will start a new
        // presentation.
        if (mSession.getPresentationId() == null) {
            final FloatingActionButton fab = (FloatingActionButton) rootView.findViewById(
                    R.id.play_presentation_fab);
            fab.setVisibility(View.VISIBLE);
            fab.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    // TODO(kash): Implement me.
//                    mRole = Role.PRESENTER;
//                    fab.setVisibility(View.INVISIBLE);
//                    PresentationActivity activity = (PresentationActivity) v.getContext();
//                    activity.startPresentation();
                }
            });
        }
        mRecyclerView = (RecyclerView) rootView.findViewById(R.id.slide_list);
        mRecyclerView.setHasFixedSize(true);

        mLayoutManager = new LinearLayoutManager(container.getContext(),
                LinearLayoutManager.VERTICAL, false);
        mRecyclerView.setLayoutManager(mLayoutManager);

        return rootView;
    }

    @Override
    public void onStart() {
        super.onStart();
        DB db = DB.Singleton.get();
        mAdapter = new SlideListAdapter(mRecyclerView, db, mSession);
        mRecyclerView.setAdapter(mAdapter);
    }

    @Override
    public void onStop() {
        super.onStop();
        mAdapter.stop();
        mAdapter = null;
    }

    @Override
    public void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        outState.putString(SESSION_ID_KEY, mSession.getId());
    }

    private void handleError(String msg, Throwable throwable) {
        Log.e(TAG, msg + ": " + Log.getStackTraceString(throwable));
        Toast.makeText(getContext(), msg, Toast.LENGTH_SHORT).show();
    }

}
