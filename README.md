# ScheduleMe

ScheduleMe is an Android-first, offline personal scheduler for recurring household and personal tasks.

## Development

Install Flutter and an Android SDK, then run:

```text
flutter pub get
flutter test
flutter run
```

All task data and optional attachments remain on the device. The app has no account, network, or Azure dependency.

The SQLite schema is versioned under `lib/core/database/migrations/` and is applied by `AppDatabase` when the local database is opened.
