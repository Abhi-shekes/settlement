# Settlement — Expense Tracking & Bill Splitting

A Flutter + Firebase app for personal expense tracking, budgeting, and splitting
bills with friends and groups. Every multi‑party action is a **two‑sided
handshake** — splits, settlements, friend requests, and group invites only take
effect once the other party confirms — and each event triggers a **push
notification** via Firebase Cloud Messaging.

> **Stack:** Flutter (Dart 3.7+) · Firebase Auth (Google Sign‑In) · Cloud
> Firestore · Cloud Messaging · Cloud Functions (Node 20) · Provider

---

## Table of contents

- [Features](#features)
- [Architecture](#architecture)
- [Project structure](#project-structure)
- [Data model](#data-model)
- [Getting started](#getting-started)
- [Firebase configuration](#firebase-configuration)
- [Push notifications](#push-notifications)
- [Running & building](#running--building)
- [Deploying the backend](#deploying-the-backend)
- [Testing](#testing)
- [Security model](#security-model)
- [Roadmap & known limitations](#roadmap--known-limitations)

---

## Features

### Authentication & social
- **Google Sign‑In** with automatic user‑profile creation and a unique friend code.
- **Friend requests** — adding a friend (by friend code or email) sends a request
  that the other person must **accept**; the friendship forms only on acceptance.

### Personal finance
- **Expense tracking** across 8 categories with search, edit, and delete. Group
  expenses are excluded from personal totals so nothing is double‑counted.
- **Budgets** — per‑category monthly limits with 80%‑near‑limit and over‑budget
  alerts, plus progress visualizations.
- **Analytics** — weekly / monthly / yearly spend charts (via `fl_chart`) and a
  splits breakdown.

### Splitting & settling (the handshake)
- **Split a bill** equally or with custom amounts. Amounts are divided to the
  paisa so shares always sum back to the exact total.
- **Per‑person approval** — a participant's share only becomes a real debt once
  **that participant approves it**. Balances post atomically on approval.
- **Settle up with confirmation** — recording a payment creates a *pending*
  settlement; balances move only when the **counterparty confirms** it.
- **Groups** — roles (admin/member), member management, group balances, and email
  invitations that require acceptance.

### Notifications & requests
- **Requests inbox** — one screen (with a live badge) to accept/decline every
  pending item: friend requests, split approvals, payment confirmations, group
  invites. Also surfaced inline in the Friends and Splits screens.
- **Push notifications (FCM)** for all of the above, delivered by Cloud Functions.

---

## Architecture

The app follows a lightweight layered architecture with **Provider** for state:

```
UI (screens/, widgets/)
        │  context.read/watch
Services (ChangeNotifier)      ← business logic, Firestore access, local cache
        │
Models (plain Dart, fromMap/toMap)
        │
Cloud Firestore  ──▶  Cloud Functions (Firestore triggers → FCM)
```

- **Services** (`lib/services/`) are `ChangeNotifier`s registered in
  `main.dart` via `MultiProvider`. They own the Firestore reads/writes and an
  in‑memory cache, and call `notifyListeners()` on change.
- **Balance‑affecting writes run in Firestore transactions** so concurrent
  expenses/settlements can't clobber each other.
- **Money is split in integer paise** (`lib/utils/money.dart`) to avoid
  floating‑point drift.

---

## Project structure

```
lib/
├── main.dart                  # App entry, providers, auth gate, FCM bootstrap
├── models/                    # Plain data models (fromMap/toMap)
│   ├── user_model.dart
│   ├── group_model.dart
│   ├── expense_model.dart
│   ├── split_model.dart       # + SettlementModel, ParticipantStatus, SettlementStatus
│   ├── budget_model.dart
│   ├── group_invitation_model.dart
│   └── friend_request_model.dart
├── services/                  # ChangeNotifier services
│   ├── auth_service.dart      # Google auth, friends, friend requests
│   ├── expense_service.dart
│   ├── group_service.dart     # groups, splits, approvals, settlements
│   ├── budget_service.dart
│   ├── invitation_service.dart
│   └── notification_service.dart  # FCM tokens, permissions, local notifications
├── screens/
│   ├── auth/ home/ dashboard/ expenses/ splits/ groups/ budgets/
│   ├── analytics/ profile/ invitations/
│   └── requests/              # central handshake inbox
├── utils/money.dart           # exact even-split helper
└── widgets/                   # shared UI (budget cards, dialogs)

functions/                     # Cloud Functions (Node 20) — FCM fan-out
firestore.rules                # Security rules
firestore.indexes.json         # Composite indexes
firebase.json                  # Firestore + Functions deploy config
test/                          # Unit tests
```

---

## Data model

Firestore collections:

| Collection | Key fields | Notes |
|---|---|---|
| `users` | `uid`, `email`, `friendCode`, `friends[]`, `groups[]`, `fcmTokens[]` | One doc per user |
| `groups` | `adminId`, `memberIds[]`, `balances{uid→amount}`, `expenseIds[]` | Net balances per member |
| `expenses` | `userId`, `amount`, `category`, `groupId?` | Personal + group expenses |
| `splits` | `paidBy`, `participants[]`, `splitAmounts{}`, `participantStatus{}`, `settlements[]` | Approvals + settlements embedded |
| `budgets` | `userId`, `category`, `amount`, `month` | Per category, per month |
| `group_invitations` | `groupId`, `inviteeEmail`, `status` | 7‑day expiry |
| `friend_requests` | `fromUserId`, `toUserId`, `status` | Pending/accepted/declined |

**Handshake state lives on the split**: `participantStatus[uid]` is
`pending`/`accepted`/`declined`, and each embedded settlement has a
`status` (`pending`/`confirmed`/`rejected`) plus `recordedBy` (the counterparty
confirms). Legacy documents without these fields are treated as
already‑accepted / already‑confirmed for backward compatibility.

---

## Getting started

### Prerequisites
- **Flutter** SDK (Dart `>= 3.7.2`) — `flutter doctor` should pass.
- A **Firebase project** with **Cloud Firestore**, **Authentication**, and
  **Cloud Messaging** enabled.
- **Node 20** and the **Firebase CLI** (`npm i -g firebase-tools`) for the backend.
- For push delivery: the Firebase **Blaze (pay‑as‑you‑go)** plan (Cloud Functions
  make outbound calls to FCM).

### Install
```bash
git clone <repo-url>
cd settlement-app
flutter pub get
```

---

## Firebase configuration

Configuration files are **git‑ignored** and must be provided per environment.

1. **Register apps** in the Firebase console (the Android package must match
   `applicationId` in `android/app/build.gradle.kts` — currently
   `com.example.settlement`; change both together before publishing).

2. **Generate platform config** with the FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This creates `lib/firebase_options.dart` and drops
   `android/app/google-services.json` / `ios/Runner/GoogleService-Info.plist`.
   > If you generate `firebase_options.dart`, update `main.dart` to
   > `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

3. **Enable Google Sign‑In** under Authentication → Sign‑in method, and add your
   SHA‑1/SHA‑256 fingerprints to the Android app in the console.

---

## Push notifications

The client (`NotificationService`) requests permission, stores each device's FCM
token in the user's `fcmTokens[]`, and shows a local notification for foreground
messages. Delivery to other users is done by **Cloud Functions** that trigger on
Firestore writes:

| Event | Who gets notified |
|---|---|
| Friend request created / accepted | recipient / sender |
| Split created | each participant ("approve your share") |
| Settlement recorded | the counterparty ("confirm a payment") |
| Settlement confirmed / rejected | the person who recorded it |
| Share approved / declined | the payer |
| Group invitation created | the invitee (resolved by email) |

**iOS additionally requires**: an Apple Developer account, an **APNs auth key**
uploaded to Firebase, and the Push Notifications capability enabled in Xcode.
Android works once the functions are deployed.

---

## Running & building

```bash
# Run on a connected device / emulator
flutter run

# Analyze & format
flutter analyze
dart format .

# Debug APK
flutter build apk --debug

# Release build (see signing below)
flutter build appbundle --release
```

### Release signing
Release builds are signed from a **git‑ignored** `android/key.properties`
(template: `android/key.properties.example`). Without it, the build falls back to
the debug keystore for local development only.

```properties
# android/key.properties
storePassword=…
keyPassword=…
keyAlias=…
storeFile=/absolute/path/to/your-release-key.jks
```

---

## Deploying the backend

```bash
firebase use --add            # select your Firebase project (first time)

# Firestore security rules + composite indexes
firebase deploy --only firestore

# Cloud Functions (requires the Blaze plan)
cd functions && npm install && cd ..
firebase deploy --only functions
```

The composite indexes in `firestore.indexes.json` back the expense, split,
budget, invitation, and friend‑request queries — deploy them or those queries
will fail with `failed-precondition`.

---

## Testing

```bash
flutter test
```

Unit tests cover the pure business logic:
- `test/money_test.dart` — even‑split math sums back to the exact total.
- `test/split_model_test.dart` — approval status, confirmed‑only settlement
  accounting, and settlement‑confirmer direction.

---

## Security model

- **Firestore rules** (`firestore.rules`) scope access to the data owner:
  budgets are private; expenses are owner + group‑member readable; splits are
  participant‑only; group writes are limited to members (a user may only add
  *themselves* on invite‑accept); friend requests are visible only to the two
  parties.
- **Handshake integrity** — a debt or settlement only affects balances after the
  counterparty confirms, preventing one‑sided balance changes.
- **Transactions** guard every balance mutation against race conditions.
- **Secrets are git‑ignored** — keystores, `key.properties`,
  `google-services.json`, and `firebase_options.dart` are never committed.

---

## License

Proprietary — all rights reserved (update as appropriate).
