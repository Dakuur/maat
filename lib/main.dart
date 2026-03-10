import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/services/firebase_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kiosk UX: lock to portrait and hide system UI chrome.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Populate Firestore with demo data.
  // force: true → re-seeds classes with today's timestamps on every cold start.
  try {
    await FirebaseService.instance.seedMockDataIfNeeded(force: true);
  } catch (e) {
    // Seeding is best-effort; the app can still run without pre-seeded data.
    debugPrint('Seed skipped: $e');
  }

  runApp(const MaatKioskApp());
}
