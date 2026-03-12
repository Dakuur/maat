import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/app_user.dart';
import '../../data/services/auth_service.dart';

const _usersCollection = 'users';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  bool _loading = false;
  bool _needsTrainingPlan = false;
  String? _error;

  AppUser? get user => _user;
  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null;
  bool get needsTrainingPlan => _needsTrainingPlan;
  String? get error => _error;

  final _db = FirebaseFirestore.instance;

  AuthProvider() {
    AuthService.instance.authStateChanges.listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _needsTrainingPlan = false;
      notifyListeners();
      return;
    }

    // Optimistically set user from Firebase Auth data so the UI updates
    // immediately, even before Firestore responds.
    _user = AppUser(
      uid: firebaseUser.uid,
      displayName: firebaseUser.displayName ?? '',
      email: firebaseUser.email,
      photoUrl: firebaseUser.photoURL,
    );
    notifyListeners();

    try {
      final ref = _db.collection(_usersCollection).doc(firebaseUser.uid);
      final doc = await ref.get();

      if (doc.exists) {
        _user = AppUser.fromFirestore(doc);
      } else {
        await ref.set({
          'displayName': firebaseUser.displayName ?? '',
          'email': firebaseUser.email,
          'photoUrl': firebaseUser.photoURL,
          'trainingPlan': null,
          'createdAt': Timestamp.now(),
        });
      }

      _needsTrainingPlan = _user?.trainingPlan == null;
      notifyListeners();
    } on FirebaseException catch (e) {
      // Firestore rules not yet configured — user is still logged in via Auth,
      // but we can't read/write their profile. Show the training plan prompt
      // anyway so they can proceed.
      debugPrint('AuthProvider Firestore error: ${e.code} — ${e.message}');
      _needsTrainingPlan = true;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await AuthService.instance.signInWithGoogle();
      // _onAuthChanged fires automatically via the stream
    } catch (e) {
      _error = 'Sign-in failed. Please try again.';
      notifyListeners();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
  }

  Future<void> setTrainingPlan(String plan) async {
    if (_user == null) return;
    await _db
        .collection(_usersCollection)
        .doc(_user!.uid)
        .update({'trainingPlan': plan});
    _user = _user!.copyWith(trainingPlan: plan);
    _needsTrainingPlan = false;
    notifyListeners();
  }
}
