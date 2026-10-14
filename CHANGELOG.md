# Changelog

## 1.1.0

- Added selection and permanent deletion by day, app, or individual notification.
- Reduced history-list transfer cost by excluding serialized Android PendingIntent data that the list UI does not use. Original action data remains stored locally for opening a notification.
- Kept notification archives local in indexed SQLite storage and retained the existing JSON-to-SQLite upgrade path.
- Included dark theme, optional donation page, privacy disclosure, and onboarding.
