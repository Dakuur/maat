# MAAT Kiosk — Submission

## Contact

**David Morillo** — davidmormas@gmail.com · +34 722 112 127

---

## Tested Platforms

| Platform | Status |
|----------|--------|
| Android (physical device) | Tested |
| Chrome (Flutter Web) | Tested |
| iOS | Not tested — no device available |

---

## Architecture

The app follows a three-layer architecture:

```
Services → Providers → Screens/Widgets
```

- **Services** (`lib/data/services/`): single access point for all external I/O. `FirebaseService` is a singleton that owns every Firestore operation (read, write, batch, stream). `AuthService` wraps Google Sign-In. `CalendarService` calls the Google Calendar REST API.
- **Providers** (`lib/presentation/providers/`): four `ChangeNotifier` classes that own state and expose it to the UI. No business logic in widgets.
- **Screens & Widgets** (`lib/presentation/screens/`, `lib/presentation/widgets/`): purely reactive — they read from providers and call provider methods. Navigation is centralised in `AppRouter` (named routes + `PageRouteBuilder` transitions).

---

## Tech Stack

| Layer | Choice |
|-------|--------|
| Platform | Flutter 3.41.4 / Dart 3.11.1 — Android (primary) + iOS |
| Database | Cloud Firestore — real-time streams, offline persistence |
| Auth | Firebase Auth + Google Sign-In |
| State | Provider (`ChangeNotifier`) |
| Font | Geist variable font — local asset (165 KB, all weights in one file) |
| External API | Google Calendar REST (read-only, `calendar.readonly` scope) |
| Seeding | Python + `firebase-admin` (`scripts/seed.py`) |

Key packages: `cloud_firestore`, `firebase_auth`, `google_sign_in`, `cached_network_image`, `animations`, `intl`, `flutter_dotenv`, `uuid`.

---

## What Was Built

The brief asked for five screens and a client-side data layer. This submission goes further:

| Brief requirement | Status |
|------------------|--------|
| Home screen with today's classes | Done — live Firestore stream, class cards with capacity indicator |
| Class detail with attendee list | Done — real-time stream, check-in time, status badge |
| Member search (client-side filter) | Done — instant local filter across 40 seeded members |
| Member check-in confirmation | Done — live capacity check, over-capacity override dialog |
| Success screen, auto-reset to home | Done — 5 s countdown, animated check icon, fireworks burst, bobbing avatars |

Beyond the brief:

- **Google Sign-In** — staff profile stored in Firestore `users/{uid}`, training plan prompt on first login
- **Personal "Join class"** — logged-in user can enrol themselves; shown in a dedicated "You" section with green highlight
- **Bulk check-in / bulk remove** — multi-select (long-press) + single WriteBatch write — no intermediate list flicker
- **Optimistic remove** — items fade out immediately; Firestore delete runs in background
- **Timeline calendar** — 80 px/hour grid, dynamic start hour (classes before 06:00 are never clipped), swipe navigation between days
- **Google Calendar sync** — fetches ±7 days in one call, conflict detection (gym class overlaps personal event → warning icon), joined classes take visual priority over conflicts
- **Offline-first** — Firestore local persistence serves cached data; queued writes flush on reconnect
- **Resilience** — 10 s timeout on all Firestore writes, network error SnackBar, inline timeout banner
- **Python seeder** — 40 members, full weekly BJJ/Muay Thai schedule, randomised check-ins, `--wipe` / `--dry-run` flags

---

## Design Decisions

**Firebase/Firestore instead of local JSON.**
The brief recommends local JSON for simplicity. I chose Firestore because real-time `snapshots()` streams eliminate the need to manually reconcile state after writes — the UI just reacts. Offline persistence comes for free. The tradeoff is a heavier dependency and a required Firebase project to run the app.

**Singleton `FirebaseService`.**
All four providers share one Firestore connection and one set of collection references. This avoids duplicate listeners and redundant auth token refreshes.

**`WriteBatch` for every multi-document write.**
Bulk check-in, bulk remove, and single check-in all use `WriteBatch`. Either all documents land in Firestore or none do — `attendeeCount` never drifts from the actual number of `check_ins` docs.

**Auth is optional.**
The kiosk works without a logged-in staff member. Authentication gates extra features (personal join, Google Calendar, training plan) but never blocks the core check-in flow.

**`user:{uid}` prefix for staff self-check-ins.**
Staff who join a class are stored with `memberId = "user:{uid}"` instead of a member document ID. This prevents collisions, makes identity checks trivial, and keeps the `check_ins` collection schema uniform.

**`CalendarProvider` at app level.**
Google Calendar data is fetched once per day and cached in the provider. Navigating away and back does not trigger a re-fetch. Only "Re-sync" does. This avoids hammering the Calendar API on every screen transition.

**Dynamic timeline start hour.**
The calendar timeline starts at `min(06:00, earliest class start)`. If a class is seeded at 05:30, the grid extends upward automatically — nothing is clipped off the top.

---

## Trade-offs

**No unit or integration tests.**
Time constraint. The architecture (thin widgets, logic in providers/services) makes the codebase testable — mocking `FirebaseService` and injecting it into providers is straightforward. With more time, I would cover `CheckInProvider.submitCheckIn` state transitions and `FirebaseService.bulkCheckInMembers` chunking logic.

**Firestore security rules are open (`allow read, write: if true`).**
Appropriate for a kiosk prototype where staff are physically present. For production, `check_ins` writes would be restricted to authenticated users and `members`/`classes` writes to admin roles only.

**Provider over BLoC or Riverpod.**
Provider is the right complexity level for four change notifiers with straightforward state. BLoC would add boilerplate without benefit at this scale.

**`attendeeCount` is denormalized.**
Stored directly on the class document for cheap reads. `WriteBatch` keeps it in sync atomically. In a high-concurrency environment (hundreds of simultaneous check-ins), `FieldValue.increment` handles race conditions correctly on the Firestore side.

**No kiosk lock mode.**
The brief lists it as a bonus. On Android this would require `FLAG_KEEP_SCREEN_ON` + a device owner policy to disable the home button. On iOS it requires Guided Access. Neither is a Flutter concern — it is a device management decision. The app's 5-second auto-reset covers the core kiosk requirement.

---

## What I Would Add With More Time

1. **Firestore security rules** — role-based (admin vs. kiosk-only) with auth token validation
2. **QR code check-in** — member scans a QR on their phone; `mobile_scanner` reads it at the kiosk
3. **Unit + integration tests** — provider state machines, Firestore batch logic, calendar conflict detection
4. **Kiosk lock mode** — Android device owner + `FLAG_KEEP_SCREEN_ON`; iOS Guided Access API
5. **Member photo upload** — Firebase Storage + image picker for profile pictures
6. **Check-in analytics** — attendance trends per class, per member, per week

---

## Running the App

> Full setup instructions are in `README.md`. Quick start below.

**Requirements:** Flutter ≥ 3.3.0, Android Studio, Android SDK API 34, Java 17.

```bash
git clone <repo-url>
cd maat
flutter pub get
```

Create a `.env` file at the project root (get values from the project owner):

```dotenv
FIREBASE_PROJECT_ID="maat-f5d20"
GOOGLE_WEB_CLIENT_ID="21896097619-xxxx.apps.googleusercontent.com"
GOOGLE_CALENDAR_API_KEY="AIza..."
GOOGLE_CLIENT_SECRET="GOCSPX-..."
```

```bash
# Run on connected Android device / emulator / Chrome
flutter run

# Release APK (arm64, covers all modern phones)
flutter build apk --release --split-per-abi
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

**Google Sign-In** requires your debug keystore SHA-1 registered in Firebase Console → Project Settings → Android app → Add fingerprint:

```bash
# Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
# macOS / Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

The core check-in flow (Home → Class → Search → Confirm → Success) works without signing in.
