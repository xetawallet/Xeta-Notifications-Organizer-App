# Xeta Notifications Organizer

An Android notification organizer built with Flutter. **Every line of app code is open source** under the Apache 2.0 License.

- Source: https://github.com/xetawallet/Xeta-Notifications-Organizer-App
- Website: `App Code/assets/Website/build/`
- App source: `App Code/`
- Play Store graphics and screenshots: `App Code/assets/Play Store Assets-Master/`
- Build utilities: `tool/`

Notification records stay in a private SQLite database on the device. Original notification actions are reopened when Android still accepts them. If an archived action is no longer available, a captured link is opened when possible, then the originating app is launched.

## Build a test APK

```sh
cd "App Code"
flutter pub get
flutter build apk --debug
```

Debug APKs are for testing and are not Play Store releases. Release signing credentials must remain private and outside this repository.

See [`App Code/assets/privacy_policy.md`](App%20Code/assets/privacy_policy.md) for the privacy policy and [`CHANGELOG.md`](CHANGELOG.md) for release history.
