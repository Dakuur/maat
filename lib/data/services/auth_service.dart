import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _auth = FirebaseAuth.instance;

  // Only instantiated on mobile — never accessed on Web.
  // On Web we go through Firebase Auth's signInWithPopup instead, which
  // does not require the google_sign_in package at all.
  late final _googleSignIn = GoogleSignIn(
    serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    scopes: const ['email', 'profile'],
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: Firebase handles the OAuth popup natively.
      // No google_sign_in package involved — the credential type is
      // OAuthCredential, which Firebase Auth accepts directly.
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      return await _auth.signInWithPopup(provider);
    }

    // Mobile: google_sign_in → credential → Firebase Auth.
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    if (kIsWeb) {
      await _auth.signOut();
      return;
    }
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Returns an OAuth access token with the calendar.readonly scope.
  ///
  /// Web: re-authenticates via popup with the calendar scope so Firebase
  ///      returns an OAuthCredential that contains the access token.
  /// Mobile: requests the incremental scope through google_sign_in.
  Future<String?> requestCalendarAccessToken() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('https://www.googleapis.com/auth/calendar.readonly');

      // If not signed in yet, do a full sign-in with the calendar scope.
      if (_auth.currentUser == null) {
        final result = await _auth.signInWithPopup(provider);
        return (result.credential as OAuthCredential?)?.accessToken;
      }

      // Already signed in: re-authenticate to obtain the additional scope.
      final result =
          await _auth.currentUser!.reauthenticateWithPopup(provider);
      return (result.credential as OAuthCredential?)?.accessToken;
    }

    // Mobile: use google_sign_in's incremental scope request.
    if (_googleSignIn.currentUser == null) {
      final result = await signInWithGoogle();
      if (result == null) return null;
    }
    final granted = await _googleSignIn.requestScopes(
      ['https://www.googleapis.com/auth/calendar.readonly'],
    );
    if (!granted) return null;
    final auth = await _googleSignIn.currentUser?.authentication;
    return auth?.accessToken;
  }
}
