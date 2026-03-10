# MAAT Kiosk

A portrait-only, touch-first gym check-in kiosk built with Flutter and Firebase. Members tap their class, find their name, and confirm their attendance — the whole flow takes under five seconds.

---

## Table of contents

1. [Features](#features)
2. [Architecture](#architecture)
3. [Project structure](#project-structure)
4. [Offline-first behaviour](#offline-first-behaviour)
5. [Animations](#animations)
6. [Database seeder](#database-seeder)
7. [Getting started](#getting-started)
8. [Environment & Firebase setup](#environment--firebase-setup)

---

## Features

| Feature | Details |
|---|---|
| Class schedule | Today's classes from Firestore, live-updating stream |
| Member check-in | Search by name → confirm → success in ≤ 5 s |
| Multi-select check-in | Long-press any member to batch check-in a group |
| Live capacity | `X/Y attendees` — turns red when the class is full |
| Live attendee list | Real-time updates — all kiosks always in sync |
| Remove attendee | Tap an attendee in the class detail to remove them |
| Offline support | Firestore SDK caches reads and queues writes locally |
| Haptic feedback | Medium impact on long-press; heavy impact on success |
| Pull-to-refresh | Home screen and member search list |

---

## Architecture

The app follows a **layered architecture** with a unidirectional data flow:

```
┌─────────────────────────────────────────┐
│            Presentation layer           │
│  Screens  ←→  Providers (ChangeNotifier)│
└───────────────────┬─────────────────────┘
                    │ calls
┌───────────────────▼─────────────────────┐
│             Service layer               │
│          FirebaseService (singleton)    │
└───────────────────┬─────────────────────┘
                    │ reads / writes
┌───────────────────▼─────────────────────┐
│              Data layer                 │
│   Firestore  ←→  Models (fromFirestore) │
└─────────────────────────────────────────┘
```

### Key decisions

**Singleton service** — `FirebaseService.instance` is shared across all providers. This guarantees a single `FirebaseFirestore` client, avoids duplicate listener registration, and keeps the token-refresh lifecycle centralised.

**Provider (`ChangeNotifier`)** — Chosen over Riverpod or Bloc for minimal boilerplate. The two providers map directly to the two concerns of the app:

| Provider | Concern |
|---|---|
| `ClassProvider` | Today's class schedule + live attendee list |
| `CheckInProvider` | Member list, search, check-in flow state |

Both are created at app start via `MultiProvider` in `app.dart` and live for the entire session.

**Atomic transactions** — Both `checkInMember` and `removeCheckIn` use Firestore transactions. The `check_ins` document and the `attendeeCount` field on the class are always committed together, so the count displayed in the UI is always consistent with the actual documents — even under concurrent access from multiple kiosks.

**Stream-based reactivity** — `ClassProvider` holds `StreamSubscription` objects mapped to Firestore `snapshots()` streams. The UI rebuilds automatically when any document changes — no polling, no manual refresh required.

**Client-side search** — The member list (up to a few hundred entries) is loaded once and filtered in memory on every keystroke. This gives instant feedback with zero additional Firestore reads.

---

## Project structure

```
lib/
├── core/
│   ├── constants/    app_constants.dart      — timing, layout, collection names
│   ├── router/       app_router.dart         — named routes + SharedAxisTransition
│   └── theme/        app_colors.dart         — centralised colour palette
│                     app_theme.dart          — Material 3 theme (Geist font)
│
├── data/
│   ├── models/       member.dart             — Member  (fromFirestore / toFirestore)
│   │                 fitness_class.dart      — FitnessClass + isFull computed prop
│   │                 check_in.dart           — CheckIn + CheckInStatus enum
│   └── services/     firebase_service.dart   — all Firestore I/O (singleton)
│
├── presentation/
│   ├── providers/    class_provider.dart     — class schedule + attendee stream
│   │                 checkin_provider.dart   — member list, search, check-in flow
│   ├── screens/
│   │   ├── home/               — class schedule + hero banner
│   │   ├── class_detail/       — live attendees, remove-attendee bottom sheet
│   │   ├── member_search/      — search + multi-select bulk check-in
│   │   ├── checkin_confirm/    — review card before submitting
│   │   └── success/            — animated confirmation + 3 s auto-redirect
│   └── widgets/
│       ├── class_card.dart          — ClassCard with live capacity chip
│       ├── member_list_tile.dart    — MemberListTile with multi-select support
│       ├── attendee_list_tile.dart  — AttendeeListTile for the class detail screen
│       ├── member_avatar.dart       — circular avatar with initials fallback
│       ├── kiosk_button.dart        — large 64 px button (primary / secondary / danger)
│       └── fade_slide_in.dart       — staggered fade + slide list entrance widget
│
├── utils/
│   └── db_seeder.dart    — clearDatabase / seedPartial / seedFull helpers
│
├── app.dart              — MaterialApp, MultiProvider, router wiring
└── main.dart             — Firebase init, edge-to-edge SystemChrome, app start
```

---

## Offline-first behaviour

MAAT Kiosk is fully functional without internet connectivity. The Firestore Flutter SDK ships with **local persistence enabled by default**: all documents are cached to disk and all pending writes are queued for later upload.

### Cold start offline

1. Firebase initialises from the on-device configuration — no network required.
2. `ClassProvider.watchTodaysClasses()` opens a Firestore stream. The SDK immediately emits the **last known cached snapshot** from local disk.
3. The home screen renders today's classes within milliseconds, entirely from cache.
4. The member list is served from the `members` collection cache on the first check-in attempt.

### Check-in while offline

1. The user taps a class, finds their name, and taps **Check In**.
2. `FirebaseService.checkInMember` calls `runTransaction(...)`.
3. The Firestore SDK writes the new `check_ins` document and the updated `attendeeCount` **to local cache immediately**. The transaction is marked as a pending write.
4. The `watchCheckInsForClass` stream emits the local change — the attendee appears in the list at once.
5. The success screen is shown with haptic confirmation. From the user's perspective there is no difference from an online check-in.

### Reconnection & automatic sync

When internet is restored the Firestore SDK:

1. Flushes all pending writes to the server in the order they were made.
2. Re-evaluates any transactions server-side. Because `isMemberCheckedIn` is checked inside the transaction, duplicate check-ins from concurrent offline kiosks are caught and rejected — only one succeeds.
3. Pushes any remote changes to all live listeners. `ClassProvider` receives the updated documents and the UI reflects the final server state automatically.

### Edge case: two kiosks, both offline

If two kiosks check in the same member while both are offline, both will show a local "success". When they reconnect, one transaction will succeed and the other will fail on the server (the second `checkInMember` call finds an existing record and throws `AlreadyCheckedInException`). The failed transaction is rolled back and the UI of the second kiosk would show the error — but since the success screen has already been dismissed, this is a silent reconciliation in practice. For a single-kiosk deployment this scenario is impossible.

---

## Animations

### Page transitions

All screen transitions use `SharedAxisTransition` (horizontal axis) from the [`animations`](https://pub.dev/packages/animations) package — the Material Motion shared-axis pattern. The outgoing screen fades and slides left while the incoming screen arrives from the right.

The **success screen** uses `SharedAxisTransitionType.scaled` instead, giving a distinct "zooming in" feel that reinforces the celebratory moment.

| Route | Transition | Duration |
|---|---|---|
| Home → Class Detail | Horizontal shared axis | 300 ms / 250 ms reverse |
| Class Detail → Member Search | Horizontal shared axis | 300 ms / 250 ms reverse |
| Member Search → Confirm | Horizontal shared axis | 300 ms / 250 ms reverse |
| Confirm → Success | Scaled shared axis | 300 ms / 250 ms reverse |

### List entrance animations

`FadeSlideIn` (`lib/presentation/widgets/fade_slide_in.dart`) wraps individual list items with a combined **fade-in + 7 % upward slide**, staggered by `index × 55 ms`. Both transforms run on the GPU via Flutter's compositor (`FadeTransition` / `SlideTransition`) — no `setState` fires during the animation, so there is no extra rebuild cost.

Used on:
- Class cards on the Home screen (up to 9 items, max 440 ms total stagger)
- Attendee tiles on the Class Detail screen

### Haptic feedback

| Action | Feedback |
|---|---|
| Long-press member to start multi-select | `HapticFeedback.mediumImpact()` |
| Check-in success screen appears | `HapticFeedback.heavyImpact()` |

---

## Database seeder

`DbSeeder` (`lib/utils/db_seeder.dart`) provides three static methods for populating Firestore with demo data. The seeder is completely **decoupled from the app startup** — the app reads from Firestore cold on every launch; it never seeds automatically.

### Methods

| Method | What it does |
|---|---|
| `DbSeeder.clearDatabase()` | Deletes all `classes` and `check_ins`. Members are preserved by default. |
| `DbSeeder.clearDatabase(includeMembers: true)` | Also deletes all member documents. |
| `DbSeeder.seedPartial()` | Seeds the 20 demo members using `SetOptions(merge: true)` — safe to run on a live database. |
| `DbSeeder.seedFull()` | Seeds members + today's classes + pre-assigned check-ins. Wipes classes/check-ins first so timestamps are always "today". |

### From a hidden UI button

Wire the seeder to a long-press on any hidden element (e.g. the logo):

```dart
GestureDetector(
  onLongPress: () async {
    await DbSeeder.seedFull();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database re-seeded ✓')),
      );
    }
  },
  child: const LogoWidget(),
)
```

### From a standalone Dart script

```dart
// tool/seed.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:maat_kiosk/firebase_options.dart';
import 'package:maat_kiosk/utils/db_seeder.dart';

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Clearing database…');
  await DbSeeder.clearDatabase();
  print('Seeding full demo data…');
  await DbSeeder.seedFull();
  print('Done.');
}
```

```bash
dart run tool/seed.dart
```

---

## Getting started

### Prerequisites

- Flutter 3.10+ (tested on **3.41.4**)
- Dart 3.3+
- An Android device / emulator (API 26+) or iOS 14+
- A Firebase project with **Cloud Firestore** enabled

### Install & run

```bash
git clone https://github.com/Dakuur/maat
cd maat_kiosk
flutter pub get
flutter run
```

On first launch with an empty Firestore the app shows **"No classes today"**. Seed the database from the developer button or with `DbSeeder.seedFull()`.

---

## Environment & Firebase setup

Firebase configuration files are excluded from version control. Each environment (dev / staging / prod) needs its own set:

| File | Platform |
|---|---|
| `lib/firebase_options.dart` | Generated by `flutterfire configure` |
| `android/app/google-services.json` | Android |
| `ios/Runner/GoogleService-Info.plist` | iOS / macOS |

```bash
# Install the FlutterFire CLI once
dart pub global activate flutterfire_cli

# Generate config for your project
flutterfire configure --project=<your-firebase-project-id>
```

### Recommended Firestore security rules

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Members: kiosk reads, admin writes only
    match /members/{id} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    // Classes: kiosk reads; seeder / admin writes
    match /classes/{id} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    // Check-ins: kiosk creates and deletes; no direct updates
    match /check_ins/{id} {
      allow read, create, delete: if true;
      allow update: if false;
    }
  }
}
```

---

## Tech stack

| Concern | Choice | Reason |
|---|---|---|
| Framework | Flutter 3.x | Single codebase, 120/144 Hz capable |
| Database | Firebase Cloud Firestore | Real-time streams, offline persistence |
| State | Provider (`ChangeNotifier`) | Minimal boilerplate, easy to test |
| Transitions | `animations` package | Material Motion spec, GPU-composited |
| Font | Geist variable TTF (self-hosted) | No Google Fonts network call |
| Images | `cached_network_image` | Persistent disk cache for avatars |
