# MAAT Kiosk

Touch-first gym check-in kiosk for Android and Chrome, intended for iOS but not tested. Members tap their class, find their name, confirm attendance — the whole flow takes under 5 seconds.

## Tested Platforms

| Platform | Status |
|----------|--------|
| Android (physical device) | Tested |
| Chrome (Flutter Web) | Tested |
| iOS | Not tested — no device available |

## Contact

For any questions contact the author: **David Morillo** — davidmormas@gmail.com · +34 722 112 127

---

---

## Prerequisites

Install these tools before doing anything else.

| Tool | Required version | Download |
|------|-----------------|---------|
| **Flutter SDK** | ≥ 3.3.0, < 4.0.0 (tested on 3.41.4) | https://docs.flutter.dev/get-started/install |
| **Android Studio** | Any recent version | https://developer.android.com/studio |
| **Android SDK** | API 34 (compileSdk), API 21 minimum | Android Studio → SDK Manager |
| **Java (JDK)** | 17 | Bundled with Android Studio ≥ Hedgehog |
| **Git** | Any | https://git-scm.com |

> Android Studio also installs the Android SDK, ADB, and platform tools automatically. If you prefer VS Code, install the **Flutter** and **Dart** extensions.

**Optional — only needed to seed the database:**

| Tool | Required version |
|------|-----------------|
| Python | ≥ 3.9 |

---

## Getting Started

### 1. Clone the repo

```bash
git clone <repo-url>
cd maat
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Verify your setup

```bash
flutter doctor
```

Fix any issues reported by `flutter doctor` before continuing (missing Android SDK, missing cmdline-tools, license agreements, etc.).

### 4. Connect a device or start an emulator

```bash
# List connected devices
flutter devices

# Run on the connected device/emulator
flutter run
```

The app targets Android only. If you want a specific device:

```bash
flutter run -d <device-id>
```

---

## Font Setup

The **Geist** variable font is already bundled in the repo at `assets/fonts/Geist-Variable.ttf` (165 KB) and registered in `pubspec.yaml`. **No extra steps are needed** — `flutter pub get` is sufficient.

```yaml
# pubspec.yaml (already configured)
fonts:
  - family: Geist
    fonts:
      - asset: assets/fonts/Geist-Variable.ttf
```

The `package.json` / `node_modules/` at the root are only there as the original source used to copy the TTF. You do not need Node.js to build or run the app.

---

## Credentials & Secrets — What Goes in the Repo

**Short answer:** The repo already contains everything needed to build and run the app. You do not need to create or upload any extra credential file to compile the APK. The one thing each developer must do manually is register their debug keystore SHA-1 with Firebase to enable Google Sign-In.

### What is already committed

| File | What it contains | Needed for |
|------|-----------------|-----------|
| `.env` | Firebase project ID, Google Web Client ID, Calendar API key | App runtime |
| `lib/firebase_options.dart` | Firebase platform config (API keys, app IDs) | Firebase initialization |
| `android/app/google-services.json` | Firebase Android config | Android build (google-services plugin) |

These files are listed in `.gitignore` (so they won't appear in `git status` as untracked) but were committed before the gitignore rule was added, so git continues to track them. Any collaborator who clones the repo gets them automatically.

### What is NOT committed

| File | Why it is excluded | How to get it |
|------|-------------------|--------------|
| `.env` | Contains API keys and OAuth secrets | Get it from the project owner |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS config | Firebase Console → Project Settings → iOS app → Download |
| `scripts/service-account.json` | Firebase admin key — full read/write access | Firebase Console → Service Accounts → Generate new key |

`service-account.json` is only used by the Python seeding script. It is **not required to build or run the Flutter app**.

### Android — SHA-1 requirement

Google Sign-In on Android requires your debug keystore's SHA-1 fingerprint to be registered in Firebase Console. Without it the app builds fine but the Google Sign-In button fails silently.

```bash
# macOS / Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Add the fingerprint in **Firebase Console → Project Settings → Android app → Add fingerprint**.

> For a signed release build, register the SHA-1 of your release keystore as well.

### iOS — no SHA-1, different requirements

iOS does **not** use SHA-1. Google Sign-In on iOS uses a URL scheme (`REVERSED_CLIENT_ID`) that is already configured in `ios/Runner/Info.plist` in this repo — no extra Xcode step needed. What iOS does require that is not in the repo:

1. **`.env`** — same file as Android, pass it directly to the colleague
2. **`ios/Runner/GoogleService-Info.plist`** — download from Firebase Console → Project Settings → iOS app (bundle ID `com.maat.maatKiosk`) → Download `GoogleService-Info.plist` → place it at `ios/Runner/GoogleService-Info.plist`

These two files are the only blockers for an iOS build.

---

## Running the Web Version

```bash
flutter run -d chrome
```

## Building the APK

Pre-built APKs are available in the /builds folder for testing. To build your own, use these commands:

```bash
# Install dependencies (always run this after cloning or after pubspec changes)
flutter pub get

# Debug build — hot reload enabled, runs directly on device
flutter run

# Release APK — split by CPU architecture (smallest file, install only what you need)
flutter build apk --release --split-per-abi

# Single fat APK (larger, works on all architectures)
flutter build apk --release

# Android App Bundle for Google Play
flutter build appbundle --release
```

### Install a specific APK on a device

```bash
# Check device architecture first
adb shell getprop ro.product.cpu.abi
# → arm64-v8a on almost all modern phones (2017+)

# Install
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### APK sizes (measured)

| Build | Architecture | Size |
|-------|-------------|------|
| Debug APK | universal | ~57 MB — never distribute |
| Release | arm64-v8a | **18.7 MB** — all modern phones |
| Release | armeabi-v7a | 16.3 MB — older / 32-bit |
| Release | x86_64 | 20.0 MB — emulators / Chromebooks |

Size breakdown: Firebase SDK ~8 MB · Flutter engine ~5 MB · Dart code + assets (Geist font 165 KB + logos) < 0.5 MB.

---

## Features

### Check-In Flow
- Browse today's class schedule on the Home screen
- Tap a class → view live attendee list
- Search for a member by name → confirm check-in
- **Animated success screen**: floating member avatar(s), elastic check icon, fireworks burst, 5-second countdown with auto-redirect
- Bulk check-in: long-press a member to enter multi-select, check in multiple at once

### Google Authentication
- Staff sign in with Google via the Home screen header button
- Profile photo and name saved to Firestore `users/{uid}` on first login
- Training plan selection dialog on first sign-in (Unlimited / 3x / 2x / 1x / Drop-in)
- Sign-out clears Google Calendar sync data so no data leaks between accounts

### Personal Join Class
- When signed in, the class detail screen shows a **"You"** section at the top
- Staff can join a class as a participant with "Join as [name]"
- Joined classes show a **green border + "You're in" badge** on Home and Calendar

### Weekly Schedule Calendar
- Calendar icon in the Home header opens a **Timeline view** (dynamic start hour, 80 px/hour)
- Navigate between days with `<` / `>` arrows, swipe left/right, or tap the label to jump to Today
- Red current-time indicator on Today's view
- Tap any class block to open its detail screen

### Google Calendar Sync
- "Sync with Google" button fetches **±7 days** in a single API call (15-day window)
- Sync data **persists** while the app is open — navigating away and back does not require re-syncing
- **Conflict detection**: gym class overlaps a personal calendar event → warning icon + red-tinted block
- **Joined takes priority**: enrolled classes stay green even when conflicting
- Sign-out clears the event cache

### Multi-Select & Bulk Operations
- Long-press an attendee to enter multi-select mode
- Bulk remove: single `WriteBatch` → one network round-trip, one stream event, no list flicker
- Bulk check-in from member search (chunked `whereIn` + one batch write)

---

## Architecture

```
lib/
├── app.dart                        # MultiProvider root + MaterialApp
├── main.dart                       # Bootstrap: dotenv, Firebase init, orientation lock
├── core/
│   ├── constants/app_constants.dart
│   ├── router/app_router.dart      # Named routes, cross-fade + scale transitions
│   └── theme/                      # AppColors, AppTheme (Geist variable font)
├── data/
│   ├── models/                     # FitnessClass, Member, CheckIn, AppUser,
│   │                               # CalendarEvent, CheckedInPerson
│   └── services/
│       ├── auth_service.dart       # Google Sign-In wrapper + calendar scope request
│       ├── calendar_service.dart   # Google Calendar REST API (range fetch)
│       └── firebase_service.dart   # All Firestore operations
└── presentation/
    ├── providers/
    │   ├── auth_provider.dart      # Auth state + users/{uid} lifecycle
    │   ├── calendar_provider.dart  # App-level: day nav, class fetch, GCal cache, conflicts
    │   ├── class_provider.dart     # Today's classes stream + check-ins + myJoinedClassIds
    │   └── checkin_provider.dart   # Single check-in flow state machine
    ├── screens/
    │   ├── home/                   # Schedule list + hero banner + login button
    │   ├── calendar/               # Timeline view + swipe nav + Google Calendar sync
    │   ├── class_detail/           # Live attendee list + personal join + bulk remove
    │   ├── member_search/          # Fuzzy search + bulk check-in
    │   ├── checkin_confirm/        # Confirmation card with capacity guard
    │   └── success/                # Animated: multi-avatar float + fireworks + countdown
    └── widgets/                    # ClassCard, MemberAvatar, KioskButton, AttendeeListTile…
scripts/
├── seed.py                         # Python seeder (members + weekly schedule + check-ins)
└── requirements.txt                # firebase-admin
```

**State management**: `provider` (`ChangeNotifier`)
**Font**: [Geist](https://vercel.com/font) — variable weight, local asset (165 KB)
**CalendarProvider** lives at app level so Google Calendar sync persists across navigation

---

## Firestore Collections

| Collection | Purpose |
|-----------|---------|
| `members` | Gym member profiles (seeded by `scripts/seed.py`) |
| `classes` | Weekly schedule — Mon–Sat, seeded for N weeks |
| `check_ins` | Individual check-in records (classId + memberId) |
| `users` | Authenticated staff accounts (displayName, email, photoUrl, trainingPlan) |

### Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /members/{doc}   { allow read, write: if true; }
    match /classes/{doc}   { allow read, write: if true; }
    match /check_ins/{doc} { allow read, write: if true; }
  }
}
```

---

## Database Seeding

All seeding is done via the Python script. The Flutter app contains no seeding logic.

```bash
cd scripts
pip install -r requirements.txt
# Place service-account.json here (Firebase Console → Project Settings → Service Accounts)

python seed.py                          # 30 members, 9 weeks, 2–8 check-ins/class
python seed.py --members 50             # custom member count
python seed.py --weeks 12               # ~3 months of classes
python seed.py --max-checkins 12        # busier classes
python seed.py --wipe                   # wipe everything first, then seed
python seed.py --wipe-checkins          # keep members, reset check-ins
python seed.py --dry-run                # preview without writing
```

**Default schedule** (23 classes/week × 9 weeks = 207 classes):

| Day | Classes |
|-----|---------|
| Monday | BJJ Fundamentals · Muay Thai Basics · Open Mat · BJJ/Grappling |
| Tuesday | Wrestling · BJJ/Grappling · Muay Thai Advanced · No-Gi |
| Wednesday | BJJ Fundamentals · Open Mat · Muay Thai Basics · BJJ/Grappling · MMA Conditioning |
| Thursday | Muay Thai Basics · No-Gi · BJJ Advanced · Wrestling |
| Friday | BJJ Fundamentals · Muay Thai Advanced · Open Mat · BJJ/Grappling · MMA Conditioning |
| Saturday | Open Mat |
| Sunday | — |

---

## Route Transitions

All routes use `PageRouteBuilder` with a solid `ColoredBox` backing — no black flash between screens:

| Transition | Duration | Effect |
|-----------|---------|--------|
| Standard push | 280 ms | Cross-fade |
| Standard pop | 220 ms | Cross-fade |
| Calendar day swipe | 300 ms | Slide + fade |
| Success screen | 380 ms | Scale 0.94→1 + fade |
| Success reverse | 260 ms | Scale + fade |

## Tools used for the App:

- PyCharm as IDE
- Python for helpful scripts such as seed.py (not for production)
- Google stack:
 - Firebase as database
 - Google Authentication as log-in/sign up methon
 - Flutter for unified mobile + web integration
 - Google Calendar as an example integration
- AI:
 - Google Gemini for investigation (great research tool and well-connected to the internet for documentation). Also used to explain front-end code and documentation help.
 - Claude Code to write code (mostly font-end) and agentic use for testing and live bug fixing.
