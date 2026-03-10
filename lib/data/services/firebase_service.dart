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

  /// Members successfully checked in during this call.
  final int ok;

  /// Members that were already registered in the class (skipped).
  final int alreadyIn;

  /// Members whose write failed due to a Firestore error.
  final int failed;

  bool get hasAnyResult => ok > 0 || alreadyIn > 0 || failed > 0;
}

/// Single access point for all Firestore operations.
///
/// Architecture: singleton so every [Provider] and screen shares the same
/// [FirebaseFirestore] connection, avoiding duplicate listeners and redundant
/// auth token usage.
///
/// Offline-first: Firestore's local persistence is enabled by default in the
/// Flutter SDK. All read/write operations are optimistically cached on-device;
/// when the device is offline the SDK serves cached data and queues writes.
/// Once connectivity is restored, queued writes are flushed automatically and
/// live listeners receive any remote changes — zero manual reconciliation.
///
/// Collections:
/// - `members`   — gym member profiles (stable, long-lived documents)
/// - `classes`   — today's fitness class schedule (created fresh by seeder)
/// - `check_ins` — individual check-in records, referenced by classId/memberId
class FirebaseService {
  FirebaseService._();

  /// Global singleton — inject via [FirebaseService.instance].
  static final FirebaseService instance = FirebaseService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _members =>
      _db.collection(AppConstants.membersCollection);

  CollectionReference<Map<String, dynamic>> get _classes =>
      _db.collection(AppConstants.classesCollection);

  CollectionReference<Map<String, dynamic>> get _checkIns =>
      _db.collection(AppConstants.checkInsCollection);

  // ── Seeding ──────────────────────────────────────────────────────────────

  /// Seeds Firestore with demo data.
  ///
  /// - Members: written with merge (stable, never deleted).
  /// - Classes + check-ins: wiped and re-created every time so timestamps
  ///   are always "today" and attendeeCounts match real check-in documents.
  Future<void> seedMockDataIfNeeded({bool force = false}) async {
    // ── Members (idempotent) ─────────────────────────────────────────────────
    final memberSnap = await _members.limit(1).get();
    if (memberSnap.docs.isEmpty || force) {
      final memberBatch = _db.batch();
      for (final m in _mockMembers) {
        memberBatch.set(
          _members.doc(m['id'] as String),
          {
            'firstName': m['firstName'],
            'lastName': m['lastName'],
            'profilePicture': m['profilePicture'],
            'memberSince': m['memberSince'],
            'plan': m['plan'],
          },
          SetOptions(merge: true),
        );
      }
      await memberBatch.commit();
    }

    // ── Wipe old classes and check-ins ──────────────────────────────────────
    final oldClasses = await _classes.get();
    final oldCheckIns = await _checkIns.get();
    final delBatch = _db.batch();
    for (final doc in oldClasses.docs) { delBatch.delete(doc.reference); }
    for (final doc in oldCheckIns.docs) { delBatch.delete(doc.reference); }
    if (oldClasses.docs.isNotEmpty || oldCheckIns.docs.isNotEmpty) {
      await delBatch.commit();
    }

    // ── Create classes with fixed IDs (so check-ins can reference them) ─────
    final today = DateTime.now();
    final classes = _mockClassesWithIds(today);
    final classBatch = _db.batch();
    for (final c in classes) {
      final id = c['id'] as String;
      final data = Map<String, dynamic>.from(c)..remove('id');
      classBatch.set(_classes.doc(id), data);
    }
    await classBatch.commit();

    // ── Create pre-seeded check-ins ──────────────────────────────────────────
    final memberMap = {for (final m in _mockMembers) m['id'] as String: m};
    final classMap = {for (final c in classes) c['id'] as String: c};
    final checkinBatch = _db.batch();

    for (final entry in _mockCheckInAssignments.entries) {
      final classId = entry.key;
      final classData = classMap[classId]!;
      final startTime = (classData['startTime'] as Timestamp).toDate();

      for (int i = 0; i < entry.value.length; i++) {
        final memberId = entry.value[i];
        final m = memberMap[memberId]!;
        // stagger check-in times: earliest 45 min before class, then +3 min
        final checkinAt = startTime.subtract(Duration(minutes: 45 - i * 3));
        checkinBatch.set(_checkIns.doc(), {
          'memberId': memberId,
          'classId': classId,
          'memberName': '${m['firstName']} ${m['lastName']}',
          'memberProfilePicture': m['profilePicture'],
          'checkedInAt': Timestamp.fromDate(checkinAt),
          'status': CheckInStatus.confirmed.name,
        });
      }
    }
    await checkinBatch.commit();
  }

  /// Deletes all classes and check-ins. Pass [includeMembers] to also wipe members.
  Future<void> clearDatabase({bool includeMembers = false}) async {
    final classes = await _classes.get();
    final checkIns = await _checkIns.get();
    final batch = _db.batch();
    for (final doc in classes.docs) { batch.delete(doc.reference); }
    for (final doc in checkIns.docs) { batch.delete(doc.reference); }
    if (includeMembers) {
      final members = await _members.get();
      for (final doc in members.docs) { batch.delete(doc.reference); }
    }
    await batch.commit();
  }

  /// Seeds only members (idempotent – uses merge, safe to run repeatedly).
  Future<void> seedMembersOnly() async {
    final batch = _db.batch();
    for (final m in _mockMembers) {
      batch.set(
        _members.doc(m['id'] as String),
        {
          'firstName': m['firstName'],
          'lastName': m['lastName'],
          'profilePicture': m['profilePicture'],
          'memberSince': m['memberSince'],
          'plan': m['plan'],
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  // ── Members ───────────────────────────────────────────────────────────────

  /// Returns all members ordered alphabetically by last name.
  ///
  /// One-time fetch — suitable for populating the check-in search list.
  /// Uses Firestore's local cache when offline; the SDK transparently
  /// falls back to the cache and the Future still resolves successfully.
  Future<List<Member>> getMembers() async {
    final snap = await _members.orderBy('lastName').get();
    return snap.docs.map(Member.fromFirestore).toList();
  }

  // ── Classes ───────────────────────────────────────────────────────────────

  /// Real-time stream of all classes whose [startTime] falls within today.
  ///
  /// The stream emits a new list whenever any class document changes
  /// (e.g. [attendeeCount] incremented after a check-in). The Firestore SDK
  /// multiplexes this into a single persistent WebSocket connection.
  ///
  /// Offline behaviour: the stream continues emitting cached data. New events
  /// are re-emitted when connectivity is restored and remote state diverges.
  Stream<List<FitnessClass>> watchTodaysClasses() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return _classes
        .where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('startTime')
        .snapshots()
        .map((s) => s.docs.map(FitnessClass.fromFirestore).toList());
  }

  // ── Check-ins ─────────────────────────────────────────────────────────────

  /// Real-time stream of all check-in records for [classId], sorted by time.
  ///
  /// Used by [ClassDetailScreen] to show the live attendee list. The stream
  /// is cancelled via [ClassProvider.stopWatchingCheckIns] when leaving the
  /// screen to free the Firestore listener.
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

  /// Removes a single check-in atomically (transaction).
  /// For bulk removals prefer [bulkRemoveCheckIns].
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

  /// Removes multiple check-ins in **one** [WriteBatch].
  ///
  /// All deletes and the single attendeeCount decrement are committed
  /// atomically — either every write succeeds or none does. This replaces
  /// N sequential round-trips with a single network request, eliminating
  /// the repeated stream emissions that cause list flicker.
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
  /// For bulk additions prefer [bulkCheckInMembers].
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

  /// Checks in multiple members in **one** [WriteBatch].
  ///
  /// Steps:
  ///  1. One `whereIn` query (chunked at 30 — Firestore SDK limit) to
  ///     discover which members are already registered. Zero UI blocking.
  ///  2. One [WriteBatch] with all new check-in documents + a single
  ///     `attendeeCount` increment. The batch is atomic and fires a single
  ///     stream event, so the attendee list rebuilds exactly once.
  ///
  /// Returns a [BulkCheckInResult] with tallies for ok / already-in / failed.
  Future<BulkCheckInResult> bulkCheckInMembers({
    required List<Member> members,
    required FitnessClass fitnessClass,
  }) async {
    if (members.isEmpty) return const BulkCheckInResult.empty();

    // ── 1. Detect already-checked-in members (chunked whereIn) ───────────────
    final memberIds = members.map((m) => m.id).toList();
    final Set<String> alreadyInIds = {};
    const chunkSize = 30; // Firestore whereIn limit
    for (var i = 0; i < memberIds.length; i += chunkSize) {
      final chunk = memberIds.sublist(i, min(i + chunkSize, memberIds.length));
      final snap = await _checkIns
          .where('classId', isEqualTo: fitnessClass.id)
          .where('memberId', whereIn: chunk)
          .get();
      alreadyInIds
          .addAll(snap.docs.map((d) => d.data()['memberId'] as String));
    }

    final toAdd = members.where((m) => !alreadyInIds.contains(m.id)).toList();
    if (toAdd.isEmpty) {
      return BulkCheckInResult(
        ok: 0,
        alreadyIn: alreadyInIds.length,
        failed: 0,
      );
    }

    // ── 2. Single WriteBatch: all new docs + one attendeeCount increment ──────
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
      return BulkCheckInResult(
        ok: toAdd.length,
        alreadyIn: alreadyInIds.length,
        failed: 0,
      );
    } catch (_) {
      return BulkCheckInResult(
        ok: 0,
        alreadyIn: alreadyInIds.length,
        failed: toAdd.length,
      );
    }
  }

  // ── Mock data ─────────────────────────────────────────────────────────────

  static const _mockMembers = [
    // ── Active members ────────────────────────────────────────────────────
    {
      'id': 'mem_001',
      'firstName': 'Anna',
      'lastName': 'Rossi',
      'plan': 'Unlimited',
      'memberSince': '2023-01-15',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Anna+Rossi&background=E87D3E&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_002',
      'firstName': 'Marco',
      'lastName': 'Lopez',
      'plan': 'Unlimited',
      'memberSince': '2022-09-01',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Marco+Lopez&background=30A046&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_003',
      'firstName': 'Sofia',
      'lastName': 'García',
      'plan': '3x / week',
      'memberSince': '2023-03-20',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Sofia+Garcia&background=0066CC&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_004',
      'firstName': 'Luca',
      'lastName': 'Bianchi',
      'plan': 'Unlimited',
      'memberSince': '2021-11-05',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Luca+Bianchi&background=D70015&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_005',
      'firstName': 'Emma',
      'lastName': 'Martínez',
      'plan': '3x / week',
      'memberSince': '2023-06-10',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Emma+Martinez&background=4B44C8&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_006',
      'firstName': 'Noah',
      'lastName': 'Williams',
      'plan': 'Unlimited',
      'memberSince': '2022-02-28',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Noah+Williams&background=E07B00&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_007',
      'firstName': 'Isabella',
      'lastName': 'Brown',
      'plan': '2x / week',
      'memberSince': '2023-08-14',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Isabella+Brown&background=34AADC&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_008',
      'firstName': 'James',
      'lastName': 'Smith',
      'plan': 'Unlimited',
      'memberSince': '2020-05-22',
      'profilePicture':
          'https://ui-avatars.com/api/?name=James+Smith&background=636366&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_009',
      'firstName': 'Valentina',
      'lastName': 'Colombo',
      'plan': '3x / week',
      'memberSince': '2023-01-03',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Valentina+Colombo&background=FF3B30&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_010',
      'firstName': 'Carlos',
      'lastName': 'Torres',
      'plan': 'Unlimited',
      'memberSince': '2022-07-19',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Carlos+Torres&background=30B0C7&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_011',
      'firstName': 'Yuki',
      'lastName': 'Tanaka',
      'plan': 'Unlimited',
      'memberSince': '2021-04-11',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Yuki+Tanaka&background=5856D6&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_012',
      'firstName': 'Rafael',
      'lastName': 'Oliveira',
      'plan': 'Unlimited',
      'memberSince': '2022-12-01',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Rafael+Oliveira&background=34C759&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_013',
      'firstName': 'Camille',
      'lastName': 'Dupont',
      'plan': '3x / week',
      'memberSince': '2023-09-05',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Camille+Dupont&background=FF9500&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_014',
      'firstName': 'Diego',
      'lastName': 'Hernández',
      'plan': 'Unlimited',
      'memberSince': '2020-08-30',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Diego+Hernandez&background=AF52DE&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_015',
      'firstName': 'Priya',
      'lastName': 'Patel',
      'plan': '2x / week',
      'memberSince': '2024-01-08',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Priya+Patel&background=FF2D55&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_016',
      'firstName': 'Ethan',
      'lastName': 'Johnson',
      'plan': 'Unlimited',
      'memberSince': '2021-06-17',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Ethan+Johnson&background=007AFF&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_017',
      'firstName': 'Mia',
      'lastName': 'Schneider',
      'plan': '3x / week',
      'memberSince': '2023-02-25',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Mia+Schneider&background=FF6B6B&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_018',
      'firstName': 'Kenji',
      'lastName': 'Yamamoto',
      'plan': 'Unlimited',
      'memberSince': '2022-04-04',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Kenji+Yamamoto&background=1C1C1E&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_019',
      'firstName': 'Laura',
      'lastName': 'Fernández',
      'plan': '2x / week',
      'memberSince': '2023-11-12',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Laura+Fernandez&background=00C7BE&color=fff&size=256&bold=true',
    },
    {
      'id': 'mem_020',
      'firstName': 'Aleksei',
      'lastName': 'Volkov',
      'plan': 'Unlimited',
      'memberSince': '2021-09-29',
      'profilePicture':
          'https://ui-avatars.com/api/?name=Aleksei+Volkov&background=8E8E93&color=fff&size=256&bold=true',
    },
  ];

  // attendeeCount mirrors the length of each list in _mockCheckInAssignments.
  static List<Map<String, dynamic>> _mockClassesWithIds(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    return [
      // ── Morning ───────────────────────────────────────────────────────────
      {
        'id': 'cls_001',
        'name': 'BJJ Fundamentals',
        'instructor': 'Lauren S.',
        'startTime': Timestamp.fromDate(d.add(const Duration(hours: 7))),
        'endTime': Timestamp.fromDate(d.add(const Duration(hours: 8))),
        'tags': ['BJJ', 'Beginner', 'Gi'],
        'maxCapacity': 20,
        'attendeeCount': 9,
      },
      {
        'id': 'cls_002',
        'name': 'Muay Thai Basics',
        'instructor': 'Carlos R.',
        'startTime': Timestamp.fromDate(d.add(const Duration(hours: 8, minutes: 30))),
        'endTime': Timestamp.fromDate(d.add(const Duration(hours: 9, minutes: 30))),
        'tags': ['Muay Thai', 'Striking', 'Beginner'],
        'maxCapacity': 20,
        'attendeeCount': 5,
      },
      {
        'id': 'cls_003',
        'name': 'BJJ / Grappling',
        'instructor': 'Mike T.',
        'startTime': Timestamp.fromDate(d.add(const Duration(hours: 9, minutes: 30))),
        'endTime': Timestamp.fromDate(d.add(const Duration(hours: 10, minutes: 30))),
        'tags': ['BJJ', 'Intermediate', 'Gi'],
        'maxCapacity': 15,
        'attendeeCount': 13,
      },
      // ── Midday ────────────────────────────────────────────────────────────
      {
        'id': 'cls_004',
        'name': 'Open Mat',
        'instructor': 'Lauren S.',
        'startTime': Timestamp.fromDate(d.add(const Duration(hours: 12))),
        'endTime': Timestamp.fromDate(d.add(const Duration(hours: 13, minutes: 30))),
        'tags': ['Open Mat', 'All Levels'],
        'maxCapacity': 30,
        'attendeeCount': 11,
      },
      {
        'id': 'cls_005',
        'name': 'Wrestling / Takedowns',
        'instructor': 'Ana V.',
        'startTime': Timestamp.fromDate(d.add(const Duration(hours: 13, minutes: 30))),
        'endTime': Timestamp.fromDate(d.add(const Duration(hours: 14, minutes: 30))),
        'tags': ['Wrestling', 'Takedowns', 'All Levels'],
        'maxCapacity': 18,
        'attendeeCount': 7,
      },
      // ── Evening ───────────────────────────────────────────────────────────
      {
        'id': 'cls_006',
        'name': 'Muay Thai Advanced',
        'instructor': 'Carlos R.',
        'startTime': Timestamp.fromDate(d.add(const Duration(hours: 17))),
        'endTime': Timestamp.fromDate(d.add(const Duration(hours: 18))),
        'tags': ['Muay Thai', 'Striking', 'Advanced'],
        'maxCapacity': 16,
        'attendeeCount': 14,
      },
      {
        'id': 'cls_007',
        'name': 'BJJ / Grappling',
        'instructor': 'Ana V.',
        'startTime': Timestamp.fromDate(d.add(const Duration(hours: 18, minutes: 15))),
        'endTime': Timestamp.fromDate(d.add(const Duration(hours: 19, minutes: 15))),
        'tags': ['BJJ', 'Advanced', 'Gi'],
        'maxCapacity': 15,
        'attendeeCount': 10,
      },
      {
        'id': 'cls_008',
        'name': 'No-Gi Grappling',
        'instructor': 'Mike T.',
        'startTime': Timestamp.fromDate(d.add(const Duration(hours: 19, minutes: 30))),
        'endTime': Timestamp.fromDate(d.add(const Duration(hours: 20, minutes: 30))),
        'tags': ['No-Gi', 'Grappling', 'Intermediate'],
        'maxCapacity': 20,
        'attendeeCount': 8,
      },
      {
        'id': 'cls_009',
        'name': 'MMA Conditioning',
        'instructor': 'Lauren S.',
        'startTime': Timestamp.fromDate(d.add(const Duration(hours: 20, minutes: 30))),
        'endTime': Timestamp.fromDate(d.add(const Duration(hours: 21, minutes: 30))),
        'tags': ['MMA', 'Conditioning', 'All Levels'],
        'maxCapacity': 25,
        'attendeeCount': 6,
      },
    ];
  }

  /// Maps each class ID → list of member IDs to pre-seed as check-ins.
  /// List lengths MUST match each class's attendeeCount above.
  static const _mockCheckInAssignments = {
    'cls_001': [
      'mem_001', 'mem_002', 'mem_003', 'mem_004', 'mem_005',
      'mem_006', 'mem_007', 'mem_008', 'mem_009',
    ],
    'cls_002': [
      'mem_001', 'mem_003', 'mem_006', 'mem_010', 'mem_013',
    ],
    'cls_003': [
      'mem_002', 'mem_004', 'mem_007', 'mem_010', 'mem_011',
      'mem_012', 'mem_013', 'mem_014', 'mem_015', 'mem_016',
      'mem_017', 'mem_018', 'mem_019',
    ],
    'cls_004': [
      'mem_001', 'mem_002', 'mem_003', 'mem_004', 'mem_005',
      'mem_006', 'mem_007', 'mem_008', 'mem_009', 'mem_010',
      'mem_011',
    ],
    'cls_005': [
      'mem_005', 'mem_007', 'mem_009', 'mem_011', 'mem_013',
      'mem_015', 'mem_017',
    ],
    'cls_006': [
      'mem_001', 'mem_002', 'mem_003', 'mem_004', 'mem_005',
      'mem_006', 'mem_007', 'mem_008', 'mem_009', 'mem_010',
      'mem_011', 'mem_012', 'mem_013', 'mem_014',
    ],
    'cls_007': [
      'mem_001', 'mem_003', 'mem_005', 'mem_007', 'mem_009',
      'mem_011', 'mem_013', 'mem_015', 'mem_017', 'mem_019',
    ],
    'cls_008': [
      'mem_002', 'mem_004', 'mem_006', 'mem_008', 'mem_010',
      'mem_012', 'mem_014', 'mem_016',
    ],
    'cls_009': [
      'mem_003', 'mem_005', 'mem_007', 'mem_009', 'mem_011', 'mem_013',
    ],
  };
}

class AlreadyCheckedInException implements Exception {
  const AlreadyCheckedInException();

  @override
  String toString() => 'Member is already checked in to this class.';
}
