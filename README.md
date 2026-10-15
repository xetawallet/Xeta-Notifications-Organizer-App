# Xeta Notifications Organizer v1.1.2

An Android notification organizer built with Flutter. Notification records are kept in an app-private SQLite database on the device. No notification archive is sent to a server.

## Features

- Organize saved notifications by day, app, or notification.
- Select and permanently delete records by day, app, or individual notification.
- Mark notifications read, star them, and reopen their original Android notification action when it is still available.
- Configure important and repetitive apps, notification access, and dark theme.
- Review the local data disclosure and optional donation page.
- Upgrade existing date-based JSON archives into SQLite; legacy files are removed only after the import transaction succeeds.

## Source layout

- `App Code/` contains the Flutter and Android project.
- `tool/` contains APK and Play Store asset utilities.
- Generated APKs and signing files belong outside this repository.

## Build a test APK

```sh
cd "App Code"
flutter pub get
flutter build apk --debug
```

Or from the repository root:

```sh
python3 tool/build_apk.py test --app-slug xeta-notifications-organizer-v1.1.0
```

The helper writes artifacts to the sibling `Not Uploaded to Github/APK's (Test,Uploaded and To be Uploaded)/Test` directory. A debug APK is for testing and is not a Play Store release.

## Privacy and signing

See [`App Code/assets/privacy_policy.md`](App%20Code/assets/privacy_policy.md). Do not commit `android/key.properties`, keystores, local SDK paths, APKs, or app data. Release builds require a privately configured signing key.
