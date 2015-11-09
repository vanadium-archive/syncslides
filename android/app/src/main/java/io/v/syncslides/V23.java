// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import io.v.android.libs.security.BlessingsManager;
import io.v.android.v23.V;
import io.v.android.v23.services.blessing.BlessingCreationException;
import io.v.android.v23.services.blessing.BlessingService;
import io.v.syncslides.db.DB;
import io.v.v23.context.VContext;
import io.v.v23.security.BlessingPattern;
import io.v.v23.security.Blessings;
import io.v.v23.security.VPrincipal;
import io.v.v23.security.VSecurity;
import io.v.v23.verror.VException;
import io.v.v23.vom.VomUtil;

/**
 * Handles Vanadium initialization.
 */
public class V23 {

    private static final String TAG = "V23";
    private static final int BLESSING_REQUEST = 201;
    private Context mContext;
    private VContext mVContext;
    private Blessings mBlessings = null;

    public static class Singleton {
        private static volatile V23 instance;

        public static V23 get() {
            V23 result = instance;
            if (instance == null) {
                synchronized (Singleton.class) {
                    result = instance;
                    if (result == null) {
                        instance = result = new V23();
                    }
                }
            }
            return result;
        }
    }

    // Singleton.
    private V23() {
    }

    public void init(Context context, Activity activity) throws InitException {
        if (mBlessings != null) {
            return;
        }
        mContext = context;
        mVContext = V.init(mContext);
        Blessings blessings = loadBlessings();
        if (blessings == null) {
            // Get the signed-in user's email to generate the blessings from.
            String userEmail = SignInActivity.getUserEmail(mContext);
            activity.startActivityForResult(
                    BlessingService.newBlessingIntent(mContext, userEmail), BLESSING_REQUEST);
            return;
        }
        configurePrincipal(blessings);
    }

    /**
     * To be called from an Activity's onActivityResult method, e.g.
     *     public void onActivityResult(int requestCode, int resultCode, Intent data) {
     *         try {
     *             if (V23.Singleton.get().onActivityResult(
     *                     getApplicationContext(), requestCode, resultCode, data)) {
     *               return;
     *             }
     *         } catch (InitException e) {
     *             // Handle the error, possibly by resetting blessings and syncbase.
     *         }
     */
    public boolean onActivityResult(
            Context context, int requestCode, int resultCode, Intent data) throws InitException {
        if (requestCode != BLESSING_REQUEST) {
            return false;
        }
        try {
            Log.d(TAG, "unpacking blessing");
            byte[] blessingsVom = BlessingService.extractBlessingReply(resultCode, data);
            Blessings blessings = (Blessings) VomUtil.decode(blessingsVom, Blessings.class);
            BlessingsManager.addBlessings(mContext, blessings);
            configurePrincipal(blessings);
        } catch (BlessingCreationException e) {
            throw new InitException(e);
        } catch (VException e) {
            throw new InitException(e);
        }
        return true;
    }

    private Blessings loadBlessings() throws InitException {
        try {
            // See if there are blessings stored in shared preferences.
            return BlessingsManager.getBlessings(mContext);
        } catch (VException e) {
            throw new InitException(e);
        }
    }

    private void configurePrincipal(Blessings blessings) throws InitException {
        try {
            VPrincipal p = V.getPrincipal(mVContext);
            p.blessingStore().setDefaultBlessings(blessings);
            p.blessingStore().set(blessings, new BlessingPattern("..."));
            VSecurity.addToRoots(p, blessings);
            mBlessings = blessings;
            DB.Singleton.get().init(mContext);
        } catch (VException e) {
            throw new InitException(
                    String.format("Couldn't set local blessing %s", blessings), e);
        }
    }

    /**
     * v23 operations that require a blessing (almost everything) will fail if
     * attempted before this is true.
     *
     * The simplest usage is 1) There are no blessings. 2) An activity starts
     * and calls V23Manager.init. 2) init notices there are no blessings and
     * calls startActivityForResult 3) meanwhile, the activity and/or its
     * components still run, but can test isBlessed before attempting anything
     * requiring blessings. The activity will soon be re-initialized anyway. 4)
     * user kicked over into 'account manager', gets a blessing, and the
     * activity is restarted, this time with isBlessed == true.
     */
    public boolean isBlessed() {
        return mBlessings != null;
    }

    /**
     * Returns the blessings for this process.
     */
    public Blessings getBlessings() {
        return mBlessings;
    }

    /**
     * Returns the Vanadium context for this process.
     */
    public VContext getVContext() {
        return mVContext;
    }

}
