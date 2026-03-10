// ============================================================
//  IMPORTANT — replace this file with your own config.
//
//  Steps:
//    1. Create a Firebase project at https://console.firebase.google.com
//    2. Install the CLI:  dart pub global activate flutterfire_cli
//    3. Run in this directory: flutterfire configure
//
//  The command above auto-generates this file with real values.
// ============================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        ),
    };
  }

  // ── Replace all placeholder values below ──────────────────────────────────

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAfEcRJXa33PEVulMnDXv4d131XVQSg8-8',
    appId: '1:21896097619:web:116917377f7d163f88bba6',
    messagingSenderId: '21896097619',
    projectId: 'maat-f5d20',
    authDomain: 'maat-f5d20.firebaseapp.com',
    storageBucket: 'maat-f5d20.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBBSiIyl61huSRNlqEMTkpxMbpWMES1gPY',
    appId: '1:21896097619:android:e7b9b6f7be5e84d588bba6',
    messagingSenderId: '21896097619',
    projectId: 'maat-f5d20',
    storageBucket: 'maat-f5d20.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA36EEjOYj1U6RlxbvyEnvW-TE7Y1feBec',
    appId: '1:21896097619:ios:dba0cd116aca6a1588bba6',
    messagingSenderId: '21896097619',
    projectId: 'maat-f5d20',
    storageBucket: 'maat-f5d20.firebasestorage.app',
    iosBundleId: 'com.maat.maatKiosk',
  );

}