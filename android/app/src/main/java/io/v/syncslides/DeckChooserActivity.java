// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.syncslides;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.support.v4.widget.DrawerLayout;
import android.support.v7.app.AppCompatActivity;
import android.util.Log;
import android.view.Menu;
import android.widget.Toast;

import io.v.syncslides.V23;

public class DeckChooserActivity extends AppCompatActivity
        implements NavigationDrawerFragment.NavigationDrawerCallbacks {

    private static final String TAG = "DeckChooser";
    /**
     * Fragment managing the behaviors, interactions and deck of the navigation
     * drawer.
     */
    private NavigationDrawerFragment mNavigationDrawerFragment;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Immediately initialize V23, possibly sending user to the
        // AccountManager to get blessings.
        try {
            V23.Singleton.get().init(getApplicationContext(), this);
        } catch (InitException e) {
            // TODO(kash): Start a to-be-written SettingsActivity that makes it possible
            // to wipe the state of syncbase and/or blessings.
            handleError("Failed to init", e);
        }

        setContentView(R.layout.activity_deck_chooser);

        mNavigationDrawerFragment = (NavigationDrawerFragment)
                getSupportFragmentManager().findFragmentById(R.id.navigation_drawer);
        // Set up the drawer.
        mNavigationDrawerFragment.setUp(
                R.id.navigation_drawer,
                (DrawerLayout) findViewById(R.id.drawer_layout));
    }

    @Override
    public void onNavigationDrawerItemSelected(int position) {
        // update the main content by replacing fragments
        FragmentManager fragmentManager = getSupportFragmentManager();
        fragmentManager.beginTransaction()
                .replace(R.id.container, DeckChooserFragment.newInstance(position + 1))
                .commit();
    }

    public void onSectionAttached(int number) {
        switch (number) {
            case 1:
                Log.i(TAG, "Switched to account " + getString(R.string.title_account1));
                break;
            case 2:
                Log.i(TAG, "Switched to account " + getString(R.string.title_account2));
                break;
            case 3:
                Log.i(TAG, "Switched to account " + getString(R.string.title_account3));
                break;
        }
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        if (!mNavigationDrawerFragment.isDrawerOpen()) {
            // Only show items in the action bar relevant to this screen
            // if the drawer is not showing. Otherwise, let the drawer
            // decide what to show in the action bar.
            getMenuInflater().inflate(R.menu.deck_chooser, menu);
            return true;
        }
        return super.onCreateOptionsMenu(menu);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        try {
            if (V23.Singleton.get().onActivityResult(
                    getApplicationContext(), requestCode, resultCode, data)) {
                return;
            }
        } catch (InitException e) {
            // TODO(kash): Start a to-be-written SettingsActivity that makes it possible
            // to wipe the state of syncbase and/or blessings.
            handleError("Failed onActivityResult initialization", e);
        }
        // Any other activity results would be handled here.
    }

    private void handleError(String msg, Throwable throwable) {
        Log.e(TAG, msg + ": " + Log.getStackTraceString(throwable));
        Toast.makeText(getApplicationContext(), msg, Toast.LENGTH_SHORT).show();
    }
}
