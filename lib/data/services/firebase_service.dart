import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/check_in.dart';
import '../models/fitness_class.dart';
import '../models/member.dart';

/// Result returned by [FirebaseService.bulkCheckInMembers].
class BulkCheckInResult {
  const BulkCheckInResult({
    required this.ok,
    required this.alreadyIn,
    required this.failed,
  });

  const BulkCheckInResult.empty() : ok = 0, alreadyIn = 0, failed = 0;

  final int ok;
  final int alreadyIn;
  final int failed;

  bool get hasAnyResult => ok > 0 || alreadyIn > 0 || failed > 0;
}

/// Single access point for all Firestore operations.
///
/// Architecture: singleton so every Provider and screen shares the same
/// FirebaseFirestore connection, avoiding duplicate listeners and redundant
/// auth token usage.
///
/// Offline-first: Firestore's local persistence is enabled by default.
/// All reads/writes are cached on-device; queued writes flush automatically
/// when connectivity resumes. Zero manual reconciliation needed.
///
/// Collections:
/// - `members`   — gym member profiles (seeded by scripts/seed.py)
/// - `classes`   — weekly schedule (Mon–Sat, seeded by scripts/seed.py)
/// - `check_ins` — individual check-in records per classId/memberId
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _members =>
      _db.collection(AppConstants.membersCollection);

  CollectionReference<Map<String, dynamic>> get _classes =>
      _db.collection(AppConstants.classesCollection);

  CollectionReference<Map<String, dynamic>> get _checkIns =>
      _db.collection(AppConstants.checkInsCollection);

  // ── Members ───────────────────────────────────────────────────────────────

  /// Returns all members ordered alphabetically by last name.
  /// One-time fetch; uses Firestore cache when offline.
  Future<List<Member>> getMembers() async {
    final snap = await _members.orderBy('lastName').get();
    return snap.docs.map(Member.fromFirestore).toList();
  }

  // ── Classes ───────────────────────────────────────────────────────────────

  /// One-shot fetch of classes for any given [day] (used by CalendarProvider).
  Future<List<FitnessClass>> fetchClassesForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _classes
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('startTime')
        .get();
    return snap.docs.map(FitnessClass.fromFirestore).toList();
  }

  /// Real-time stream of classes whose startTime falls within today.
  ///
  /// Emits a new list whenever any class document changes (e.g. attendeeCount
  /// incremented after check-in). Continues emitting cached data when offline.
  Stream<List<FitnessClass>> watchTodaysClasses() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _classes
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('startTime')
        .snapshots()
        .map((s) => s.docs.map(FitnessClass.fromFirestore).toList());
  }

  // ── Check-ins ─────────────────────────────────────────────────────────────

  /// Stream of class IDs where [memberId] has an active check-in.
  /// Used to highlight "joined" classes on the Home and Calendar screens.
  Stream<Set<String>> watchUserCheckInClassIds(String memberId) {
    return _checkIns
        .where('memberId', isEqualTo: memberId)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()['classId'] as String).toSet());
  }

  /// Real-time stream of all check-in records for [classId], sorted by time.
  Stream<List<CheckIn>> watchCheckInsForClass(String classId) {
    return _checkIns
        .where('classId', isEqualTo: classId)
        .orderBy('checkedInAt')
        .snapshots()
        .map((s) => s.docs.map(CheckIn.fromFirestore).toList());
  }

  Future<bool> isMemberCheckedIn({
    required String memberId,
    required String classId,
  }) async {
    final snap = await _checkIns
        .where('memberId', isEqualTo: memberId)
        .where('classId', isEqualTo: classId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Removes a single check-in atomically.
  Future<void> removeCheckIn({
    required String checkInId,
    required String classId,
  }) async {
    final batch = _db.batch();
    batch.delete(_checkIns.doc(checkInId));
    batch.update(_classes.doc(classId), {
      'attendeeCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  /// Removes multiple check-ins in one WriteBatch.
  /// All deletes + one attendeeCount decrement are committed atomically.
  Future<void> bulkRemoveCheckIns({
    required List<CheckIn> checkIns,
    required String classId,
  }) async {
    if (checkIns.isEmpty) return;
    final batch = _db.batch();
    for (final c in checkIns) {
      batch.delete(_checkIns.doc(c.id));
    }
    batch.update(_classes.doc(classId), {
      'attendeeCount': FieldValue.increment(-checkIns.length),
    });
    await batch.commit();
  }

  /// Records a single check-in atomically.
  Future<void> checkInMember({
    required String memberId,
    required String classId,
    required String memberName,
    String? memberProfilePicture,
  }) async {
    final alreadyIn = await isMemberCheckedIn(
      memberId: memberId,
      classId: classId,
    );
    if (alreadyIn) throw const AlreadyCheckedInException();

    final batch = _db.batch();
    batch.set(_checkIns.doc(), {
      'memberId': memberId,
      'classId': classId,
      'memberName': memberName,
      if (memberProfilePicture != null)
        'memberProfilePicture': memberProfilePicture,
      'checkedInAt': Timestamp.fromDate(DateTime.now()),
      'status': CheckInStatus.confirmed.name,
    });
    batch.update(_classes.doc(classId), {
      'attendeeCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  /// Checks in multiple members in one WriteBatch.
  ///
  /// 1. Chunked whereIn query to detect already-registered members (≤30/chunk).
  /// 2. Single WriteBatch: all new check-in docs + one attendeeCount increment.
  Future<BulkCheckInResult> bulkCheckInMembers({
    required List<Member> members,
    required FitnessClass fitnessClass,
  }) async {
    if (members.isEmpty) return const BulkCheckInResult.empty();

    final memberIds = members.map((m) => m.id).toList();
    final Set<String> alreadyInIds = {};
    const chunkSize = 30;
    for (var i = 0; i < memberIds.length; i += chunkSize) {
      final chunk = memberIds.sublist(i, min(i + chunkSize, memberIds.length));
      final snap = await _checkIns
          .where('classId', isEqualTo: fitnessClass.id)
          .where('memberId', whereIn: chunk)
          .get();
      alreadyInIds.addAll(snap.docs.map((d) => d.data()['memberId'] as String));
    }

    final toAdd = members.where((m) => !alreadyInIds.contains(m.id)).toList();
    if (toAdd.isEmpty) {
      return BulkCheckInResult(ok: 0, alreadyIn: alreadyInIds.length, failed: 0);
    }

    final batch = _db.batch();
    final now = DateTime.now();
    for (final m in toAdd) {
      batch.set(_checkIns.doc(), {
        'memberId': m.id,
        'classId': fitnessClass.id,
        'memberName': m.fullName,
        if (m.profilePicture != null) 'memberProfilePicture': m.profilePicture,
        'checkedInAt': Timestamp.fromDate(now),
        'status': CheckInStatus.confirmed.name,
      });
    }
    batch.update(_classes.doc(fitnessClass.id), {
      'attendeeCount': FieldValue.increment(toAdd.length),
    });

    try {
      await batch.commit();
      return BulkCheckInResult(ok: toAdd.length, alreadyIn: alreadyInIds.length, failed: 0);
    } catch (_) {
      return BulkCheckInResult(ok: 0, alreadyIn: alreadyInIds.length, failed: toAdd.length);
    }
  }

  /// Checks the signed-in Google user into a class.
  /// Uses memberId prefix `user:` to distinguish from gym members.
  Future<void> selfCheckIn({
    required String uid,
    required String displayName,
    String? photoUrl,
    required String classId,
  }) async {
    final memberId = 'user:$uid';
    final already = await isMemberCheckedIn(memberId: memberId, classId: classId);
    if (already) throw const AlreadyCheckedInException();

    final batch = _db.batch();
    batch.set(_checkIns.doc(), {
      'memberId': memberId,
      'classId': classId,
      'memberName': displayName,
      if (photoUrl != null) 'memberProfilePicture': photoUrl,
      'checkedInAt': Timestamp.fromDate(DateTime.now()),
      'status': CheckInStatus.confirmed.name,
    });
    batch.update(_classes.doc(classId), {'attendeeCount': FieldValue.increment(1)});
    await batch.commit();
  }
}

class AlreadyCheckedInException implements Exception {
  const AlreadyCheckedInException();

  @override
  String toString() => 'Member is already checked in to this class.';
}
