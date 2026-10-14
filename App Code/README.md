# Xeta Notifications Organizer

Local Android notification organizer, v1.0.10. Notification access stores captured notifications in the app-private SQLite database at `databases/notification_archive.db`. On upgrade, existing date-based JSON archives are imported automatically and deleted only after the database transaction succeeds.

On first launch, review and accept the notification-data disclosure. Then complete onboarding and enable notification access. Keep important apps selected if their notifications should remain in the phone shade. Non-important apps are archived and cleared when "Silence non-important apps" is on. Repetitive apps are archived as read by default.

Saved notification records can be deleted from Settings. Collection stops when Notification access is disabled in Android settings.

Build:

```bash
./release.sh
```

Card taps reuse the original notification action while Android still exposes its pending intent. Old or dismissed notifications may no longer be openable by Android.

Version 1.0.10 adds a saved dark theme, the donation page, and indexed SQLite notification storage while preserving existing JSON history during upgrade. It also keeps date-wide read actions on swipe with checkbox confirmation, separates selected and unselected app lists, and includes an in-app privacy disclosure and record deletion control.

Launcher icon uses the Apache-2.0 Material Symbols notifications shape.
