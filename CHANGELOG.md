# Changelog

## 1.1.2

- Return to Notifications when the app resumes.
- Resolve notification taps from Android's active notification actions so the original app action remains available after an app process restart.
- Restrict archived URL fallback to notifications recorded as web links.

## 1.1.1

- Show notification text in Details instead of the internal PendingIntent marker.
- Keep a bounded in-memory cache of original notification actions after shade dismissal and make the Open Action result visible.
- Use dark theme by default and allow theme changes throughout onboarding.

## 1.1.0

- Added selection and permanent deletion by day, app, or individual notification.
- Reduced history-list transfer cost by excluding serialized Android PendingIntent data that the list UI does not use. Original action data remains stored locally for opening a notification.
- Kept notification archives local in indexed SQLite storage and retained the existing JSON-to-SQLite upgrade path.
- Included dark theme, optional donation page, privacy disclosure, and onboarding.
