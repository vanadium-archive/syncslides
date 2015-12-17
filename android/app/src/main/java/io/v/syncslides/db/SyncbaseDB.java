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
import com.google.common.util.concurrent.ListenableFuture;
import com.google.common.util.concurrent.ListeningExecutorService;
import com.google.common.util.concurrent.MoreExecutors;

import org.joda.time.Duration;

import java.io.File;
import java.io.IOException;
import java.io.OutputStream;
import java.util.Arrays;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.Executors;

import io.v.android.v23.V;
import io.v.impl.google.naming.NamingUtil;
import io.v.impl.google.services.syncbase.SyncbaseServer;
import io.v.syncslides.InitException;
import io.v.syncslides.V23;
import io.v.syncslides.model.Deck;
import io.v.syncslides.model.DynamicList;
import io.v.syncslides.model.NoopList;
import io.v.syncslides.model.Session;
import io.v.syncslides.model.Slide;
import io.v.v23.context.CancelableVContext;
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
import io.v.v23.syncbase.nosql.BlobWriter;
import io.v.v23.syncbase.nosql.Database;
import io.v.v23.syncbase.nosql.Table;
import io.v.v23.verror.VException;

import static io.v.v23.VFutures.sync;

class SyncbaseDB implements DB {
    private static final String TAG = "SyncbaseDB";
    private static final String SYNCBASE_APP = "syncslides";
    private static final String SYNCBASE_DB = "syncslides";
    static final String DECKS_TABLE = "Decks";
    static final String NOTES_TABLE = "Notes";
    static final String PRESENTATIONS_TABLE = "Presentations";
    static final String UI_TABLE = "UI";
    static final String CURRENT_SLIDE = "CurrentSlide";
    static final String QUESTIONS = "questions";
    private static final String SYNCGROUP_PRESENTATION_DESCRIPTION = "Live Presentation";

    private boolean mInitialized = false;
    private Handler mHandler;
    private ListeningExecutorService mExecutorService;
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
        mExecutorService = MoreExecutors.listeningDecorator(Executors.newCachedThreadPool());

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

    // TODO(kash): Do this asynchronously so it doesn't block the UI.
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
            if (!sync(app.exists(mVContext))) {
                sync(app.create(mVContext, mPermissions));
            }
            mDB = app.getNoSqlDatabase(SYNCBASE_DB, null);
            if (!sync(mDB.exists(mVContext))) {
                sync(mDB.create(mVContext, mPermissions));
            }
            Table decks = mDB.getTable(DECKS_TABLE);
            if (!sync(decks.exists(mVContext))) {
                sync(decks.create(mVContext, mPermissions));
            }
            Table notes = mDB.getTable(NOTES_TABLE);
            if (!sync(notes.exists(mVContext))) {
                sync(notes.create(mVContext, mPermissions));
            }
            Table presentations = mDB.getTable(PRESENTATIONS_TABLE);
            if (!sync(presentations.exists(mVContext))) {
                sync(presentations.create(mVContext, mPermissions));
            }
            Table ui = mDB.getTable(UI_TABLE);
            if (!sync(ui.exists(mVContext))) {
                sync(ui.create(mVContext, mPermissions));
            }
            //importDecks();
        } catch (VException e) {
            throw new InitException("Couldn't setup syncbase service", e);
        }
        mInitialized = true;
    }

    @Override
    public String createSession(String deckId) throws VException {
        String uuid = UUID.randomUUID().toString();
        SyncbaseSession session = new SyncbaseSession(mVContext, mDB, uuid, deckId);
        session.save();
        return uuid;
    }

    @Override
    public Session getSession(String sessionId) throws VException {
        Table ui = mDB.getTable(UI_TABLE);
        CancelableVContext context = mVContext.withTimeout(Duration.millis(5000));
        VSession vSession = (VSession) sync(ui.get(context, sessionId, VSession.class));
        return new SyncbaseSession(mVContext, mDB, sessionId, vSession);
    }

    @Override
    public DynamicList<Deck> getDecks() {
        if (!mInitialized) {
            return new NoopList<>();
        }
        return new WatchedList<Deck>(mVContext, new DeckWatcher(mDB));
    }

    @Override
    public ListenableFuture<Void> importDeck(final Deck deck, final Slide[] slides) {
        return mExecutorService.submit(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                putDeck(deck);
                for (int i = 0; i < slides.length; ++i) {
                    Slide slide = slides[i];
                    putSlide(deck.getId(), i, slide);
                }
                return null;
            }
        });
    }

    private void putDeck(Deck deck) throws VException {
        Log.i(TAG, String.format("Adding deck %s, %s", deck.getId(), deck.getTitle()));
        Table decks = mDB.getTable(DECKS_TABLE);
        if (!sync(decks.getRow(deck.getId()).exists(mVContext))) {
            decks.put(
                    mVContext,
                    deck.getId(),
                    new VDeck(deck.getTitle(), deck.getThumbData()),
                    VDeck.class);
        }
    }

    private void putSlide(String prefix, int idx, Slide slide) throws VException {
        String key = slideRowKey(prefix, idx);
        Log.i(TAG, "Adding slide " + key);
        BlobWriter writer = sync(mDB.writeBlob(mVContext, null));
        try (OutputStream out = sync(writer.stream(mVContext))) {
            out.write(slide.getImageData());
        } catch (IOException e) {
            throw new VException("Couldn't write slide: " + key + ": " + e.getMessage());
        }
        writer.commit(mVContext);
        Table decks = mDB.getTable(DECKS_TABLE);
        if (!sync(decks.getRow(key).exists(mVContext))) {
            VSlide vSlide = new VSlide(slide.getThumbData(), writer.getRef().getValue());
            decks.put(mVContext, key, vSlide, VSlide.class);
        }
        Log.i(TAG, "Adding note: " + slide.getNotes());
        Table notes = mDB.getTable(NOTES_TABLE);
        notes.put(mVContext, key, new VNote(slide.getNotes()), VNote.class);
        // Update the LastViewed timestamp.
        notes.put(
                mVContext,
                NamingUtil.join(prefix, "LastViewed"),
                System.currentTimeMillis(),
                Long.class);
    }

    private String slideRowKey(String deckId, int slideNum) {
        return NamingUtil.join(deckId, "slides", String.format("%04d", slideNum));
    }
}
