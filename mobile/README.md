# Ziva Finance Mobile Companion (iOS & Android)

Cross-platform mobile companion application for **Ziva Finance**, designed with an offline-first SQLite synchronization engine, Face ID / Touch ID biometric security with background multitasking privacy masking, and instant Over-The-Air (OTA) patching via **Shorebird**.

---

## Key Architecture & Features

### 1. Biometric Security & App Switcher Masking
- **Hardware Authentication**: Integrates `local_auth` for iOS Face ID / Touch ID and Android Biometrics with device passcode fallback.
- **Startup Gate**: Enforces authentication before the portfolio dashboard or ledger is visible.
- **Lifecycle Re-locking (`WidgetsBindingObserver`)**: Automatically re-prompts Face ID when the app resumes from the background.
- **App Switcher Privacy Mask (`PrivacyShield`)**: Automatically displays a blur shield on `AppLifecycleState.paused` / `inactive`, preventing financial balance exposure in the iOS multitasking app switcher.

### 2. Offline-First SQLite Sync Engine
- **Local SQLite Storage (`sqflite`)**: Maintains indexed local caches for `local_transactions`, `local_accounts`, and the `sync_queue`.
- **Zero-Connectivity Transaction Logging**: Users can log transactions anywhere with precise timestamps and automatic cross-currency conversion.
- **Background Reconciliation (`SyncEngine`)**: Monitors network connectivity via `connectivity_plus` and pushes queued offline mutations to our BigQuery REST backend (`POST /api/transactions`) upon reconnection.

### 3. Shorebird Over-The-Air (OTA) Code Push
- **Instant Live Patching**: Configured with `shorebird.yaml` and `shorebird_code_push` to release bug fixes and new financial analytics directly to devices without waiting for App Store reviews.
- **Developer Settings Panel**: Tap the "ZIVA FINANCE" header 5 times or navigate to the Dev tab to inspect the current patch number, check for new OTA releases, inspect SQLite queue items, and trigger force syncs.

---

## Directory Layout

```
mobile/
├── pubspec.yaml                 # Flutter dependencies (local_auth, sqflite, shorebird_code_push)
├── shorebird.yaml               # Shorebird App ID & OTA channel configs
├── analysis_options.yaml        # Strict Dart linter rules
├── ios/
│   ├── Podfile                  # Deployment target iOS 14.0+
│   └── Runner/
│       ├── Info.plist           # NSFaceIDUsageDescription & dark mode configs
│       └── AppDelegate.swift    # iOS application entry
└── lib/
    ├── main.dart                # Lifecycle observer, privacy shield & biometric gate
    ├── core/
    │   ├── constants/           # BigQuery backend endpoints
    │   ├── theme/               # Dark obsidian & gold command center design tokens
    │   └── utils/               # Multi-currency conversions (ZAR, USD, ZiG)
    ├── models/
    │   ├── transaction_model.dart # BigQuery schema + sync flags
    │   ├── account_model.dart     # Three-tier accounts
    │   └── sync_queue_item.dart   # Offline queue item data model
    ├── services/
    │   ├── api_service.dart       # HTTP client to Express BigQuery backend
    │   ├── sqlite_service.dart    # SQLite database & queue CRUD
    │   ├── sync_engine.dart       # Network-aware background reconciliation
    │   ├── biometric_service.dart # Face ID / Touch ID wrapper
    │   └── shorebird_service.dart # Shorebird OTA updater service
    └── features/
        ├── auth/                  # Biometric lock screen & privacy blur shield
        ├── dashboard/             # Portfolio net worth & cash flow tiers
        ├── ledger/                # Transaction list & quick entry modal sheet
        └── settings/              # Developer panel, OTA checker & queue inspector
```

---

## Getting Started & Run Commands

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run on iOS Simulator (macOS)
```bash
# Ensure local BigQuery backend is running on http://localhost:3001
flutter run -d "iPhone 15 Pro"
```

### 3. Shorebird OTA Patching Workflow
```bash
# Initialize Shorebird app if linking to a new Shorebird cloud project:
shorebird init

# Build and release baseline binary for iOS:
shorebird release ios

# After making code edits in lib/, release an instant OTA patch:
shorebird patch ios
```
