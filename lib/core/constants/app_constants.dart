abstract final class AppConstants {
  // ── Timing ────────────────────────────────────────────────────────────────
  static const Duration successRedirectDelay = Duration(seconds: 3);

  // ── Layout ────────────────────────────────────────────────────────────────
  static const double pagePadding = 24.0;
  static const double sectionSpacing = 32.0;

  // ── Firestore collection names ────────────────────────────────────────────
  static const String membersCollection = 'members';
  static const String classesCollection = 'classes';
  static const String checkInsCollection = 'check_ins';
}
