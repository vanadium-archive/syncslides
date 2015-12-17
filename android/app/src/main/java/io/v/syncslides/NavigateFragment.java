// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides;

import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import io.v.syncslides.db.DB;
import io.v.syncslides.model.DynamicList;
import io.v.syncslides.model.ListListener;
import io.v.syncslides.model.Session;
import io.v.syncslides.model.Slide;
import io.v.v23.verror.VException;

/**
 * Provides both the presenter and audience views for navigating through a presentation.
 * Instantiated by the PresentationActivity along with other views/fragments of the presentation
 * to make transitions between them seamless.
 */
public class NavigateFragment extends Fragment {
    private static final String TAG = "NavigateFragment";
    private static final String SESSION_ID_KEY = "session_id_key";

    private Session mSession;
    private int mSlideNum = 0;
    private SlideNumberListener mSlideNumberListener = new SlideNumberListener();
    private ListListener mSlideListListener = new SlideListListener();
    private ImageView mPrevThumb;
    private ImageView mNextThumb;
    private ImageView mCurrentSlide;
    private TextView mSlideNumText;
    private EditText mNotes;
    private boolean mEditing;
    private DynamicList<Slide> mSlides;

    public static NavigateFragment newInstance(String sessionId) {
        NavigateFragment fragment = new NavigateFragment();
        Bundle args = new Bundle();
        args.putString(SESSION_ID_KEY, sessionId);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // When editing notes, display a menu with "Save".
        setHasOptionsMenu(true);
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

        final View rootView = inflater.inflate(R.layout.fragment_navigate, container, false);

//        mFabSync = rootView.findViewById(R.id.audience_sync_fab);
//        if (((PresentationActivity) getActivity()).getSynced() || mRole != Role.AUDIENCE) {
//            mFabSync.setVisibility(View.INVISIBLE);
//        } else {
//            mFabSync.setVisibility(View.VISIBLE);
//        }
//
//        mFabSync.setOnClickListener(new NavigateClickListener() {
//            @Override
//            public void onClick(View v) {
//                super.onClick(v);
//                sync();
//                mFabSync.setVisibility(View.INVISIBLE);
//            }
//        });
        View.OnClickListener previousSlideListener = new NavigateClickListener() {
            @Override
            void onNavigate() {
                previousSlide();
            }
        };
        View arrowBack = rootView.findViewById(R.id.arrow_back);
        arrowBack.setOnClickListener(previousSlideListener);
        mPrevThumb = (ImageView) rootView.findViewById(R.id.prev_thumb);
        mPrevThumb.setOnClickListener(previousSlideListener);

        View.OnClickListener nextSlideListener = new NavigateClickListener() {
            @Override
            void onNavigate() {
                nextSlide();
            }
        };
        // Show either the arrowForward or the FAB but not both.
        View arrowForward = rootView.findViewById(R.id.arrow_forward);
        View fabForward = rootView.findViewById(R.id.primary_navigation_fab);
//        if (mRole == Role.PRESENTER) {
//            arrowForward.setVisibility(View.INVISIBLE);
//            fabForward.setOnClickListener(nextSlideListener);
//        } else {
        fabForward.setVisibility(View.INVISIBLE);
        arrowForward.setOnClickListener(nextSlideListener);
//        }
        mNextThumb = (ImageView) rootView.findViewById(R.id.next_thumb);
        mNextThumb.setOnClickListener(nextSlideListener);
//        mQuestions = (ImageView) rootView.findViewById(R.id.questions);
//        // TODO(kash): Hide the mQuestions button if mRole == BROWSER.
//        mQuestions.setOnClickListener(new NavigateClickListener() {
//            @Override
//            public void onClick(View v) {
//                super.onClick(v);
//                questionButton();
//            }
//        });
        mCurrentSlide = (ImageView) rootView.findViewById(R.id.slide_current_medium);
//        mCurrentSlide.setOnClickListener(new NavigateClickListener() {
//            @Override
//            public void onClick(View v) {
//                super.onClick(v);
//                if (mRole == Role.AUDIENCE || mRole == Role.BROWSER) {
//                    ((PresentationActivity) getActivity()).showFullscreenSlide(mSlideNum);
//                }
//            }
//        });
//
        mSlideNumText = (TextView) rootView.findViewById(R.id.slide_num_text);
        mNotes = (EditText) rootView.findViewById(R.id.notes);
        mNotes.setOnFocusChangeListener(new View.OnFocusChangeListener() {
            @Override
            public void onFocusChange(View v, boolean hasFocus) {
                if (hasFocus) {
                    ((PresentationActivity) getActivity()).getSupportActionBar().show();
                    mEditing = true;
                    getActivity().invalidateOptionsMenu();
                    // We don't want the presentation to advance while the user
                    // is editing the notes.  Force the app to stay on this slide.
                    try {
                        mSession.setLocalSlideNum(mSlideNum);
                    } catch (VException e) {
                        handleFatalError("Could not set local slide num", e);
                    }
                }
            }
        });

        // The parent of mNotes needs to be focusable in order to clear focus
        // from mNotes when done editing.  We set the attributes in code rather
        // than in XML because it is too easy to add an extra level of layout
        // in XML and forget to add these attributes.
        ViewGroup parent = (ViewGroup) mNotes.getParent();
        parent.setFocusable(true);
        parent.setClickable(true);
        parent.setFocusableInTouchMode(true);

//        View slideListIcon = rootView.findViewById(R.id.slide_list);
//        slideListIcon.setOnClickListener(new NavigateClickListener() {
//            @Override
//            public void onClick(View v) {
//                super.onClick(v);
//                if (mRole == Role.AUDIENCE) {
//                    ((PresentationActivity) getActivity()).showSlideList();
//                } else {
//                    getActivity().getSupportFragmentManager().popBackStack();
//                }
//            }
//        });
//        mQuestionsNum = (TextView) rootView.findViewById(R.id.questions_num);
//        // Start off invisible for everyone.  If there are questions, this
//        // will be set to visible in the mDB.getQuestionerList() callback.
//        mQuestionsNum.setVisibility(View.INVISIBLE);
//
//        mDB = DB.Singleton.get(getActivity().getApplicationContext());
//        mDB.getSlides(mDeckId, new DB.Callback<List<Slide>>() {
//            @Override
//            public void done(List<Slide> slides) {
//                mSlides = slides;
//                // The CurrentSlideListener could have been notified while we were waiting for
//                // the slides to load.
//                if (mLoadingCurrentSlide != -1) {
//                    currentSlideChanged(mLoadingCurrentSlide);
//                }
//                updateView();
//            }
//        });
//        if (((PresentationActivity) getActivity()).getSynced()) {
//            sync();
//        } else {
//            unsync();
//        }

        return rootView;
    }

    @Override
    public void onStart() {
        super.onStart();
        ((PresentationActivity) getActivity()).setUiImmersive(true);
        mSlides = mSession.getSlides();
        mSlides.addListener(mSlideListListener);
        mSession.addSlideNumberListener(mSlideNumberListener);
    }

    @Override
    public void onStop() {
        super.onStop();
        ((PresentationActivity) getActivity()).setUiImmersive(false);
        mSession.removeSlideNumberListener(mSlideNumberListener);
        mSlides.removeListener(mSlideListListener);
        mSlides = null;
    }

    @Override
    public void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        outState.putString(SESSION_ID_KEY, mSession.getId());
    }

    @Override
    public void onCreateOptionsMenu(Menu menu, MenuInflater inflater) {
        if (mEditing) {
            inflater.inflate(R.menu.edit_notes, menu);
        }
        super.onCreateOptionsMenu(menu, inflater);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case R.id.action_save:
                saveNotes();
                return true;
        }
        return false;
    }

    /**
     * Advances to the next slide, if there is one, and updates the UI.
     */
    private void nextSlide() {
        if (mSlideNum == -1) {
            // Wait until the state has loaded before letting the user move around.
            return;
        }
        if (mSlideNum < mSession.getSlides().getItemCount() - 1) {
            try {
                mSession.setLocalSlideNum(mSlideNum + 1);
            } catch (VException e) {
                handleError("Failed to advance", e);
            }
        }
    }

    /**
     * Goes back to the previous slide, if there is one, and updates the UI.
     */
    private void previousSlide() {
        if (mSlideNum == -1) {
            // Wait until the state has loaded before letting the user move around.
            return;
        }
        if (mSlideNum > 0) {
            try {
                mSession.setLocalSlideNum(mSlideNum - 1);
            } catch (VException e) {
                handleError("Failed to go back", e);
            }
        }
    }

    private void updateView() {
        if (mSlideNum < 0 || mSlideNum >= mSlides.getItemCount()) {
            // Still loading.
            return;
        }
        if (mSlideNum > 0) {
            setThumbBitmap(mPrevThumb, mSlides.get(mSlideNum - 1).getThumb());
        } else {
            setThumbNull(mPrevThumb);
        }
        // TODO(kash): Switch to full size image.
        mCurrentSlide.setImageBitmap(mSlides.get(mSlideNum).getThumb());
        if (mSlideNum == mSlides.getItemCount() - 1) {
            setThumbNull(mNextThumb);
        } else {
            setThumbBitmap(mNextThumb, mSlides.get(mSlideNum + 1).getThumb());
        }
        if (!mSlides.get(mSlideNum).getNotes().equals("")) {
            mNotes.setText(mSlides.get(mSlideNum).getNotes());
        } else {
            mNotes.getText().clear();
        }
        mSlideNumText.setText(
                String.valueOf(mSlideNum + 1) + " of " + String.valueOf(mSlides.getItemCount()));
    }

    private void setThumbBitmap(ImageView thumb, Bitmap bitmap) {
        thumb.setImageBitmap(bitmap);
        // In landscape, the height is dependent on the image size.  However, if the
        // image was null, the height is hardcoded to 9/16 of the width in setThumbNull.
        // This resets it to the actual image size.
        if (getResources().getConfiguration().orientation == Configuration.ORIENTATION_LANDSCAPE) {
            ViewGroup.LayoutParams thumbParams = thumb.getLayoutParams();
            thumbParams.height = ViewGroup.LayoutParams.WRAP_CONTENT;
        }
    }

    private void setThumbNull(ImageView thumb) {
        thumb.setImageDrawable(null);
        // In landscape, the height is dependent on the image size.  Because we don't have an
        // image, assume all of the images are 16:9.  The width is fixed, so we can calculate
        // the expected height.
        if (getResources().getConfiguration().orientation == Configuration.ORIENTATION_LANDSCAPE) {
            ViewGroup grandparent = (ViewGroup) thumb.getParent().getParent();
            ViewGroup.LayoutParams thumbParams = thumb.getLayoutParams();
            thumbParams.height = (int) ((9 / 16.0) * grandparent.getMeasuredWidth());
        }
    }

    /**
     * If the user is editing the text field and the text has changed, save the
     * notes in Syncbase.  That will trigger a notification that the slide has
     * changed and the UI will refresh.
     */
    public void saveNotes() {
        final String notes = mNotes.getText().toString();
        if (mEditing && (!notes.equals(mSlides.get(mSlideNum).getNotes()))) {
            try {
                mSession.setNotes(mSlideNum, notes);
            } catch (VException e) {
                handleError("Could not save notes", e);
            }
        }
        mNotes.clearFocus();
        mEditing = false;
        InputMethodManager inputManager =
                (InputMethodManager) getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
        if (getActivity().getCurrentFocus() != null) {
            inputManager.hideSoftInputFromWindow(
                    getActivity().getCurrentFocus().getWindowToken(),
                    InputMethodManager.HIDE_NOT_ALWAYS);
        }
        ((PresentationActivity) getActivity()).setUiImmersive(true);
    }

    private void handleError(String msg, Throwable throwable) {
        Log.e(TAG, msg + ": " + Log.getStackTraceString(throwable));
        Toast.makeText(getContext(), msg, Toast.LENGTH_SHORT).show();
    }

    private void handleFatalError(String msg, Throwable throwable) {
        handleError(msg, throwable);
        getActivity().finish();
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
            mSlideNum = slideNum;
            updateView();
        }

        @Override
        public void onError(Exception e) {
            handleFatalError("Error listening to slide number changes", e);
        }
    }

    /**
     * If the user is editing notes and then clicks anywhere else on the screen,
     * we want that action to save the notes first.  Using this class forces
     * that behavior.
     */
    private abstract class NavigateClickListener implements View.OnClickListener {
        @Override
        public final void onClick(View v) {
            saveNotes();
            onNavigate();
        }

        /**
         * Called when there is a click.
         */
        abstract void onNavigate();
    }
}
