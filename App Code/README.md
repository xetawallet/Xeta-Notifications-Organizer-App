# Xeta Notifications Organizer app source

This directory contains the complete Flutter and Android app source for production v1.0.0, built from the tested v1.1.3 code. Every line of app code is open source under Apache 2.0.

Android version code: `1001003`.

Source repository: https://github.com/xetawallet/Xeta-Notifications-Organizer-App

Build a debug APK with `flutter pub get` followed by `flutter build apk --debug`. Configure private release signing outside this repository before making a production build.

The static app website is in `assets/Website/build/`. Source phone captures and generated Play Store screenshots are in `assets/Play Store Assets-Master/`. Regenerate the website and graphics with `python3 tool/generate_playstore_package.py` from the repository root, passing the app-specific options documented by `--help`.

The canonical app icon artwork is `assets/app_icon.svg`; the matching PNG used by the website and graphics is `assets/app_icon.png`.
