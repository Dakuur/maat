import '../data/services/firebase_service.dart';

/// Utility for seeding and clearing the Firestore database with demo data.
///
/// Use from a hidden dev button in the UI or run directly in tests/scripts.
///
/// ```dart
/// await DbSeeder.clearDatabase();   // wipe classes & check-ins
/// await DbSeeder.seedPartial();     // seed members only
/// await DbSeeder.seedFull();        // seed members + classes + check-ins
/// ```
abstract final class DbSeeder {
  /// Deletes all classes and check-ins. Members are preserved by default.
  /// Pass [includeMembers] to also delete member documents.
  static Future<void> clearDatabase({bool includeMembers = false}) =>
      FirebaseService.instance.clearDatabase(includeMembers: includeMembers);

  /// Seeds only member documents (idempotent – uses merge, safe to repeat).
  static Future<void> seedPartial() =>
      FirebaseService.instance.seedMembersOnly();

  /// Seeds members, classes, and pre-assigned check-ins.
  /// Existing classes and check-ins are wiped first so timestamps are fresh.
  static Future<void> seedFull() =>
      FirebaseService.instance.seedMockDataIfNeeded(force: true);
}
