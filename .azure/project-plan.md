# Project Plan

**Status**: Integrated
**Created**: 2026-09-22
**Mode**: NEW

---

## 1. Project Overview

**Goal**: Build ScheduleMe, an Android-first Flutter personal scheduler for recurring household and personal tasks that remains fully usable offline, supports optional task images, and makes completion history easy to review. The project is designed so that every module is independently testable.

**App Type**: Mobile app

**API Login**: No

**Mode**: NEW

**Deployment Plan**: No deployment plan found

---

## 2. Mobile — Android-first offline scheduler

| Component | Technology |
|-----------|-----------|
| **Language** | Dart |
| **Framework** | Flutter for Android-first mobile |
| **Runtime** | Dart VM / Flutter engine |
| **Package Manager** | Dart pub |
| **Test Runner** | `flutter test` |
| **Mocking Library** | Mockito |
| **Test Command** | `flutter test` |
| **Persistence** | SQLite local database for tasks, recurrence rules, and completion history; app-private local files for optional image attachments |
| **Orchestration** | None required; the app has no Azure dependency emulator |

The mobile service is Essential. The task repository, recurrence calculations, completion history, and attachment lifecycle must work without network access or account setup. The initial release has no backend, synchronization, sharing, or sign-in surface.

---

## 3. Services Required

| Azure Service | Role in App | Environment Variable | Default Value (Local) | Classification |
|---------------|------------|---------------------|----------------------|----------------|
| No Azure service required | All data remains on-device in SQLite and app-private files | — | — | Essential |

The confirmed `SQLite local database` and `Local file storage` requirements are device-local stores, not Azure resources. Do not provision cloud storage or a database for this offline-first release.

---

## 4. Prerequisites

### Run

| Tool | Service(s) | Installed | Version |
|------|------------|-----------|---------|
| Flutter SDK | mobile | ❓ | Could not be confirmed by the current shell |
| Dart SDK | mobile | ❓ | Could not be confirmed by the current shell; Flutter normally includes a compatible Dart SDK |
| Android SDK | mobile | ❓ | Android SDK directory was not found at the standard Windows location |
| Git | * | ✅ | 2.45.2.windows.1 |

### Debug

| Tool | Service(s) | Installed | Version |
|------|------------|-----------|---------|
| Android Studio | mobile | ❓ | Android Studio executable was not found at the standard Windows location |
| Android Emulator or physical Android device | mobile | ❓ | Android tooling/device availability was not confirmed |
| Flutter VS Code extension (`Dart-Code.flutter`) | mobile | ❓ | Extension folder was not found |

Double-check all `❓` tools before running the scaffolded app. No Docker, Docker Compose, browser, Azure Functions extension, or Azure emulator is required for this mobile-only plan.

---

## 5. Project Structure

```
ScheduleMe/
├── .azure/
│   └── project-plan.md
├── .gitignore
├── README.md
├── pubspec.yaml
├── analysis_options.yaml
├── android/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── database/
│   │   │   ├── app_database.dart
│   │   │   └── migrations/
│   │   ├── files/
│   │   │   └── attachment_store.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   ├── features/
│   │   ├── today/
│   │   │   ├── today_page.dart
│   │   │   └── today_controller.dart
│   │   ├── task_editor/
│   │   │   ├── task_editor_page.dart
│   │   │   └── task_editor_controller.dart
│   │   ├── task_detail/
│   │   │   └── task_detail_page.dart
│   │   ├── history/
│   │   │   └── history_page.dart
│   │   └── settings/
│   │       └── settings_page.dart
│   ├── models/
│   │   ├── task.dart
│   │   ├── recurrence_rule.dart
│   │   └── completion.dart
│   └── repositories/
│       └── task_repository.dart
└── test/
    ├── core/
    ├── features/
    ├── models/
    └── repositories/
```

Keep recurrence calculation, persistence, and file handling behind independently testable interfaces. UI controllers should depend on repositories rather than direct SQLite or filesystem calls.

---

## 6. Route Definitions

These are local Flutter navigation routes, not HTTP API endpoints. The application has no network API in this release.

| # | Method | Path | Description | Request Body | Response Body | Status Codes |
|---|--------|------|-------------|--------------|---------------|--------------|
| 1 | N/A | `/` | Today view showing due tasks and completion actions | — | Rendered Today page | — |
| 2 | N/A | `/tasks/new` | Create a task with recurrence and optional image attachment | Task draft | Persisted task and return to Today | validation error shown inline |
| 3 | N/A | `/tasks/:taskId` | View task details, edit metadata, or mark complete | Task changes | Updated task details | not found handled locally |
| 4 | N/A | `/history` | Review completion history filtered by task and date | Filter state | Local completion records | — |
| 5 | N/A | `/settings` | Configure notification and appearance preferences | Preference changes | Updated local preferences | validation error shown inline |

---

## 7. Next Steps

1. Run **azure-project-scaffold** to execute this plan
2. Run **azure-project-integrate** only if a future release adds a backend or remote synchronization
3. Run **azure-debug-plan** → **azure-debug-generate** for device/emulator and VS Code debugging configuration
4. Run the **azure-deploy** agent only if a future release introduces Azure-hosted services
