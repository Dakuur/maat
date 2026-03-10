# MAAT Kiosk

A touch-first gym check-in kiosk built with Flutter + Firebase Cloud Firestore.

---

## Architecture

```
lib/
├── core/
│   ├── constants/       # App-wide constants (timings, Firestore keys, layout)
│   ├── router/          # Named-route generator with slide transitions
│   └── theme/           # AppColors + AppTheme (Geist font, kiosk-scale sizing)
├── data/
│   ├── models/          # Member, FitnessClass, CheckIn (Firestore-serialisable)
│   └── services/        # FirebaseService singleton — all Firestore I/O
└── presentation/
    ├── providers/        # ClassProvider, CheckInProvider (ChangeNotifier)
    ├── screens/          # Home, ClassDetail, MemberSearch, CheckInConfirm, Success
    └── widgets/          # KioskButton, ClassCard, MemberAvatar, tiles
```

**Separation of concerns**: UI never touches Firestore directly — it goes through Providers → FirebaseService.

---

## Tech Stack

| Concern          | Choice                          |
|------------------|---------------------------------|
| Platform         | Flutter (Dart)                  |
| Database         | Firebase Cloud Firestore        |
| State management | Provider (`ChangeNotifier`)     |
| Font             | Geist (variable TTF, self-hosted) |
| Image caching    | `cached_network_image`          |

---

## Running the App

### Prerequisites
- Flutter SDK ≥ 3.3
- A Firebase project with Cloud Firestore enabled

### 1 — Clone & install deps
```bash
git clone https://github.com/Dakuur/maat
cd maat_kiosk
flutter pub get
```

### 2 — Configure Firebase
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
This replaces `lib/firebase_options.dart` with your project's real credentials.

### 3 — Run
```bash
flutter run
```

On first launch the app seeds **20 members** and **9 classes** for today into Firestore automatically (including pre-seeded check-in records so attendee counts are realistic from the start).

---

## Design Decisions

- **Kiosk-first sizing** — all buttons are 64 px tall; avatars 52 px+ to accommodate fat-finger taps.
- **Real-time updates** — Class attendee lists use Firestore streams (`watchCheckInsForClass`) so multiple kiosks stay in sync without polling.
- **Atomic check-in** — A Firestore transaction increments `attendeeCount` and writes the check-in document in one atomic operation, preventing race conditions.
- **Duplicate guard** — `isMemberCheckedIn` is queried before the transaction; a typed `AlreadyCheckedInException` surfaces a friendly inline banner instead of a crash.
- **Auto-reset** — `SuccessScreen` counts down from 3 and calls `pushNamedAndRemoveUntil` to clear the back-stack, returning the kiosk to a ready state.

---

## Trade-offs

| Prioritised | Deprioritised |
|-------------|---------------|
| Real-time Firestore streams | Offline-first / local cache |
| Clean architecture layers | Deep unit test coverage |
| Smooth animations on success | QR-code check-in flow |
| Duplicate check-in prevention | Admin / management screens |

---

## Future Improvements

- Offline mode with Firestore local persistence + conflict resolution
- QR-code or NFC-based check-in (no typing required)
- Kiosk lock mode (guided access / screen-pinning)
- Integration tests for the full check-in flow
- Instructor view with attendance analytics
