# MAAT Kiosk

Touch-first gym check-in kiosk for Android. Members tap their class, find their name, confirm attendance — the whole flow takes under 5 seconds.

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
- Calendar icon in the Home header opens a **Timeline view** (6:00–23:00, 80 px/hour)
- Navigate between days with `<` / `>` arrows, swipe left/right, or tap the label to jump to Today
- Red current-time indicator on Today's view
- Tap any class block to open its detail screen

### Google Calendar Sync
- "Sync with Google" button fetches **±7 days** in a single API call (15-day window)
- Sync data **persists** while the app is open — navigating away and back does not require re-syncing, only "Re-sync" does
- **Conflict detection**: gym class overlaps a personal calendar event → orange warning icon + red-tinted block
- **Joined takes priority**: if you're already enrolled in a conflicting class, it shows green (not red) — you're committed
- Sign-out clears the event cache

### Offline-First
Powered by Firestore's built-in local persistence:
- Classes and check-in lists served from cache when offline
- Writes queued locally and flushed automatically when connectivity resumes
- Attendee list stream keeps emitting cached data during network loss

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

| Collection   | Purpose |
|-------------|---------|
| `members`   | Gym member profiles (seeded by `scripts/seed.py`) |
| `classes`   | Weekly schedule — Mon–Sat, seeded for N weeks |
| `check_ins` | Individual check-in records (classId + memberId) |
| `users`     | Authenticated staff accounts (displayName, email, photoUrl, trainingPlan) |

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
# Place service-account.json here (download from Firebase Console > Service Accounts)

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

## Google APIs Setup

### 1. Firebase / Google Sign-In
1. Create Android app in Firebase Console — package `com.david.maat_kiosk`
2. Add the debug SHA-1 under Project Settings → Android app → Add fingerprint
3. Download `google-services.json` → `android/app/google-services.json`
4. Enable **Google** under Firebase Console → Authentication → Sign-in method

### 2. Google Calendar API
```
https://console.developers.google.com/apis/api/calendar-json.googleapis.com/overview?project=21896097619
```

### 3. `.env` file
```dotenv
FIREBASE_PROJECT_ID="maat-f5d20"
GOOGLE_WEB_CLIENT_ID="21896097619-xxxx.apps.googleusercontent.com"
```

---

## Building & APK Size

```bash
flutter pub get

# Development (hot reload)
flutter run

# Release APK — split by CPU architecture (install only the relevant one)
flutter build apk --release --split-per-abi

# Android App Bundle for Play Store (smallest download size)
flutter build appbundle --release
```

### APK sizes (measured)

| Build type | Size | Notes |
|-----------|------|-------|
| Debug APK | ~57 MB | Includes Dart VM + debug symbols — never distribute |
| Release arm64-v8a | **18.7 MB** | All modern Android phones (2017+) |
| Release armeabi-v7a | 16.3 MB | Older/32-bit devices |
| Release x86_64 | 20.0 MB | Emulators / Chromebooks |

The majority of the release size comes from the Firebase SDK (~8 MB) and the Flutter engine (~5 MB). The app's own code and assets (Geist font 165 KB + logos 17 KB) contribute under 0.5 MB.

**To install the right APK on a device:**
```bash
# Check device architecture
adb shell getprop ro.product.cpu.abi
# → arm64-v8a on almost all modern phones

adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## Route Transitions

All routes use `PageRouteBuilder` with a solid white `ColoredBox` backing — no black flash:

| Transition | Duration | Effect |
|-----------|---------|--------|
| Standard push | 280 ms | Cross-fade |
| Standard pop | 220 ms | Cross-fade |
| Calendar day swipe | 300 ms | Slide + fade |
| Success screen | 380 ms | Scale 0.94→1 + fade |
| Success reverse | 260 ms | Scale + fade |
