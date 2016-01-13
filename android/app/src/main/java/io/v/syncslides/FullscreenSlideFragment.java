// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides;

import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.Toast;

import io.v.syncslides.db.DB;
import io.v.syncslides.model.DynamicList;
import io.v.syncslides.model.ListListener;
import io.v.syncslides.model.Session;
import io.v.syncslides.model.Slide;
import io.v.v23.verror.VException;

public class FullscreenSlideFragment extends Fragment {
    private static final String SESSION_ID_KEY = "session_id_key";
    private static final String TAG = "FullscreenSlide";

    private Session mSession;
    private ImageView mFullScreenImage;
    private DynamicList<Slide> mSlides;
    private int mSlideNum = 0;
    private final SlideNumberListener mSlideNumberListener = new SlideNumberListener();
    private final ListListener mSlideListListener = new SlideListListener();

    public static FullscreenSlideFragment newInstance(String sessionId) {
        FullscreenSlideFragment fragment = new FullscreenSlideFragment();
        Bundle args = new Bundle();
        args.putString(SESSION_ID_KEY, sessionId);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
        Bundle bundle = savedInstanceState;
        if (bundle == null) {
            bundle = getArguments();
        }
        String sessionId = bundle.getString(SESSION_ID_KEY);
        try {
            mSession = DB.Singleton.get().getSession(sessionId);
        } catch (VException e) {
            handleFatalError("Failed to fetch Session", e);
        }
        // See comment at the top of fragment_slide_list.xml.
        ((PresentationActivity) getActivity()).setUiImmersive(true);
        // Inflate the layout for this fragment
        View rootView = inflater.inflate(R.layout.fragment_fullscreen_slide, container, false);
        mFullScreenImage = (ImageView) rootView.findViewById(R.id.fullscreen_slide_image);
        mFullScreenImage.setOnClickListener(
                v -> ((PresentationActivity) getActivity()).showNavigation());
        return rootView;
    }

    @Override
    public void onStart() {
        super.onStart();
        mSlides = mSession.getSlides();
        mSlides.addListener(mSlideListListener);
        mSession.addSlideNumberListener(mSlideNumberListener);
    }

    @Override
    public void onStop() {
        super.onStop();
        mSession.removeSlideNumberListener(mSlideNumberListener);
        mSlides.removeListener(mSlideListListener);
        mSlides = null;
    }

    @Override
    public void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        outState.putString(SESSION_ID_KEY, mSession.getId());
    }

    private void updateView() {
        if (mSlideNum < 0 ||  mSlideNum >= mSlides.getItemCount()) {
            // Still loading...
            return;
        }
        // TODO(kash): Display the fullsize image instead of the thumbnail.
        mFullScreenImage.setImageBitmap(mSlides.get(mSlideNum).getThumb());
    }

    /**
     * Updates the view whenever the list of slides changes.
     */
    private class SlideListListener implements ListListener {
        @Override
        public void notifyDataSetChanged() {
            updateView();
        }

        @Override
        public void notifyItemChanged(int position) {
            updateView();
        }

        @Override
        public void notifyItemInserted(int position) {
            updateView();
        }

        @Override
        public void notifyItemRemoved(int position) {
            updateView();
        }

        @Override
        public void onError(Exception e) {
            handleFatalError("Error watching slide list", e);
        }
    }

    private class SlideNumberListener implements Session.SlideNumberListener {
        @Override
        public void onChange(int slideNum) {
            Log.i(TAG, "onChange " + slideNum);
            mSlideNum = slideNum;
            updateView();
        }

        @Override
        public void onError(Exception e) {
            handleFatalError("Error listening to slide number changes", e);
        }
    }

    private void handleError(String msg, Throwable throwable) {
        Log.e(TAG, msg + ": " + Log.getStackTraceString(throwable));
        Toast.makeText(getContext(), msg, Toast.LENGTH_SHORT).show();
    }

    private void handleFatalError(String msg, Throwable throwable) {
        handleError(msg, throwable);
        getActivity().finish();
    }

}
