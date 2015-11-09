// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides.db;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;

import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;

import java.io.File;
import java.util.Arrays;

import io.v.android.v23.V;
import io.v.impl.google.services.syncbase.SyncbaseServer;
import io.v.syncslides.InitException;
import io.v.syncslides.V23;
import io.v.syncslides.model.Deck;
import io.v.syncslides.model.DynamicList;
import io.v.v23.context.VContext;
import io.v.v23.rpc.Server;
import io.v.v23.security.BlessingPattern;
import io.v.v23.security.Blessings;
import io.v.v23.security.access.AccessList;
import io.v.v23.security.access.Constants;
import io.v.v23.security.access.Permissions;
import io.v.v23.syncbase.Syncbase;
import io.v.v23.syncbase.SyncbaseApp;
import io.v.v23.syncbase.SyncbaseService;
import io.v.v23.syncbase.nosql.Database;
import io.v.v23.syncbase.nosql.Table;
import io.v.v23.verror.VException;

public class SyncbaseDB implements DB {
    private static final String TAG = "SyncbaseDB";
    private static final String SYNCBASE_APP = "syncslides";
    private static final String SYNCBASE_DB = "syncslides";
    private static final String DECKS_TABLE = "Decks";
    private static final String NOTES_TABLE = "Notes";
    static final String PRESENTATIONS_TABLE = "Presentations";
    static final String CURRENT_SLIDE = "CurrentSlide";
    static final String QUESTIONS = "questions";
    private static final String SYNCGROUP_PRESENTATION_DESCRIPTION = "Live Presentation";

    private boolean mInitialized = false;
    private Handler mHandler;
    private Permissions mPermissions;
    private Context mContext;
    private VContext mVContext;
    private Server mSyncbaseServer;
    private Database mDB;

    // Singleton.
    SyncbaseDB() {
    }

    @Override
    public void init(Context context) throws InitException {
        if (mInitialized) {
            return;
        }
        mContext = context;
        mHandler = new Handler(Looper.getMainLooper());

        // If blessings aren't in place, the fragment that called this
        // initialization may continue to load and use DB, but nothing will
        // work so DB methods should return noop values.  It's assumed that
        // the calling fragment will send the user to the AccountManager,
        // accept blessings on return, then re-call this init.
        if (!V23.Singleton.get().isBlessed()) {
            Log.d(TAG, "no blessings.");
            return;
        }
        mVContext = V23.Singleton.get().getVContext();
        setupSyncbase();
    }

    // TODO(kash): Run this in an AsyncTask so it doesn't block the UI.
    private void setupSyncbase() throws InitException {
        Blessings blessings = V23.Singleton.get().getBlessings();
        AccessList everyoneAcl = new AccessList(
                ImmutableList.of(new BlessingPattern("...")), ImmutableList.<String>of());
        AccessList justMeAcl = new AccessList(
                ImmutableList.of(new BlessingPattern(blessings.toString())),
                ImmutableList.<String>of());

        mPermissions = new Permissions(ImmutableMap.of(
                Constants.RESOLVE.getValue(), everyoneAcl,
                Constants.READ.getValue(), justMeAcl,
                Constants.WRITE.getValue(), justMeAcl,
                Constants.ADMIN.getValue(), justMeAcl));

        // Prepare the syncbase storage directory.
        File storageDir = new File(mContext.getFilesDir(), "syncbase");
        storageDir.mkdirs();

        try {
            String id = Settings.Secure.getString(
                    mContext.getContentResolver(), Settings.Secure.ANDROID_ID);
            mVContext = SyncbaseServer.withNewServer(mVContext, new SyncbaseServer.Params()
                    .withPermissions(mPermissions)
                            // TODO(kash): Mount it!
                            //.withName(V23Manager.syncName(id))
                    .withStorageRootDir(storageDir.getAbsolutePath()));
        } catch (SyncbaseServer.StartException e) {
            throw new InitException("Couldn't start syncbase server", e);
        }
        try {
            mSyncbaseServer = V.getServer(mVContext);
            Log.i(TAG, "Endpoints: " + Arrays.toString(mSyncbaseServer.getStatus().getEndpoints()));
            String serverName = "/" + mSyncbaseServer.getStatus().getEndpoints()[0];

            // Now that we've started Syncbase, set up our connections to it.
            SyncbaseService service = Syncbase.newService(serverName);
            SyncbaseApp app = service.getApp(SYNCBASE_APP);
            if (!app.exists(mVContext)) {
                app.create(mVContext, mPermissions);
            }
            mDB = app.getNoSqlDatabase(SYNCBASE_DB, null);
            if (!mDB.exists(mVContext)) {
                mDB.create(mVContext, mPermissions);
            }
            Table decks = mDB.getTable(DECKS_TABLE);
            if (!decks.exists(mVContext)) {
                decks.create(mVContext, mPermissions);
            }
            Table notes = mDB.getTable(NOTES_TABLE);
            if (!notes.exists(mVContext)) {
                notes.create(mVContext, mPermissions);
            }
            Table presentations = mDB.getTable(PRESENTATIONS_TABLE);
            if (!presentations.exists(mVContext)) {
                presentations.create(mVContext, mPermissions);
            }
            //importDecks();
        } catch (VException e) {
            throw new InitException("Couldn't setup syncbase service", e);
        }
        mInitialized = true;
    }
}
