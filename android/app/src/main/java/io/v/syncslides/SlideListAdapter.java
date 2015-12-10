// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides;

import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import io.v.syncslides.db.DB;
import io.v.syncslides.model.DynamicList;
import io.v.syncslides.model.ListListener;
import io.v.syncslides.model.Session;
import io.v.syncslides.model.Slide;

/**
 * Provides a list of slides to be shown in the RecyclerView of the SlideListFragment.
 */
public class SlideListAdapter extends RecyclerView.Adapter<SlideListAdapter.ViewHolder>
        implements ListListener {

    private final RecyclerView mRecyclerView;
    private DynamicList<Slide> mSlides;

    public SlideListAdapter(RecyclerView recyclerView, DB db, Session session) {
        mRecyclerView = recyclerView;
        mSlides = db.getPresentation(session).getSlides();
        mSlides.addListener(this);
    }

    @Override
    public SlideListAdapter.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.slide_card, parent, false);
        v.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                int position = mRecyclerView.getChildAdapterPosition(v);
                // TODO(kash): Implement me.
                //((PresentationActivity) v.getContext()).navigateToSlide(position);
            }
        });
        return new ViewHolder(v);
    }

    @Override
    public void onBindViewHolder(SlideListAdapter.ViewHolder holder, int position) {
        Slide slide = mSlides.get(position);
        holder.mNotes.setText(slide.getNotes());
        holder.mImage.setImageBitmap(slide.getThumb());
    }

    @Override
    public int getItemCount() {
        return mSlides.getItemCount();
    }

    @Override
    public void onError(Exception e) {
        // TODO(kash): Not sure what to do here...  Call start()/stop() to reset
        // the DynamicList?
    }

    /**
     * Stops any background monitoring of the underlying data.
     */
    public void stop() {
        mSlides.removeListener(this);
        mSlides = null;
    }


    public static class ViewHolder extends RecyclerView.ViewHolder {
        public final ImageView mImage;
        public final TextView mNotes;

        public ViewHolder(View itemView) {
            super(itemView);
            mImage = (ImageView) itemView.findViewById(R.id.slide_card_image);
            mNotes = (TextView) itemView.findViewById(R.id.slide_card_notes);
        }
    }

}
