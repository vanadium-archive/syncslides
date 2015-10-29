# SyncSlides

A simple multi-device presentation system built on [Flutter](https://flutter.io) and [Syncbase](https://github.com/vanadium/mojo.syncbase)

# Prerequisites

##Mojo

Currently, development is heavily tied to an existing installation of [Mojo](https://github.com/domokit/mojo). Please ensure that your Mojo checkout is located at `$MOJO_DIR` and has been build for Android. Instructions are available [here](https://github.com/domokit/mojo#mojo).

## Dart

Flutter depends on a relatively new version of the Dart SDK. Therefore, please ensure that you have installed the following version or greater:

```Dart VM version: 1.13.0-dev.3.1 (Thu Sep 17 10:54:54 2015) on "linux_x64"```
If you are unsure what version you are on, use `dart --version`.

To install Dart, visit the [download page](https://www.dartlang.org/downloads/).

## Android Setup

Currently Flutter requires an Android device running the Lollipop (or newer) version of the Android operating system.
`adb` tool from Android SDK needs to be installed. Please follow instructions on setting up your android device [here](http://flutter.io/getting-started/#setting-up-your-android-device)

# Running SyncSlides

Connect your Android device via USB and ensure `Android debugging` is enabled, then execute:
`
make run
`
