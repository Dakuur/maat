import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/check_in.dart';
import '../../data/models/fitness_class.dart';
import '../../data/services/firebase_service.dart';

/// Granular load state used by the UI to decide what to render.
enum LoadStatus { initial, loading, loaded, error }

/// Manages the state for today's class schedule and the live attendee list
/// of the currently viewed class.
///
/// Responsibilities:
/// - Opens / cancels Firestore stream subscriptions for classes and check-ins.
/// - Exposes derived state ([checkedInMemberIds]) so screens don't query
///   Firestore directly.
/// - Delegates mutations back to [FirebaseService] using an optimistic-UI
///   pattern: the local list is updated immediately so the UI reacts without
///   waiting for the round-trip, then writes are committed in the background.
///
/// Lifecycle: a single instance is created at app start via [MultiProvider] in
/// [app.dart] and lives for the entire app session. Streams are re-opened on
/// demand by calling [watchTodaysClasses] / [watchCheckInsForClass].
class ClassProvider extends ChangeNotifier {
  ClassProvider(this._service);

  final FirebaseService _service;

  // ── State ─────────────────────────────────────────────────────────────────
  List<FitnessClass> _todaysClasses = [];
  List<CheckIn> _currentCheckIns = [];
  Set<String> _myJoinedClassIds = {};
  LoadStatus _classesStatus = LoadStatus.initial;
  LoadStatus _checkInsStatus = LoadStatus.initial;
  String? _errorMessage;

  StreamSubscription<List<FitnessClass>>? _classesSub;
  StreamSubscription<List<CheckIn>>? _checkInsSub;
  StreamSubscription<Set<String>>? _myCheckInsSub;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<FitnessClass> get todaysClasses => _todaysClasses;
  List<CheckIn> get currentCheckIns => _currentCheckIns;
  /// Class IDs where the signed-in user (staff/trainer) is personally enrolled.
  Set<String> get myJoinedClassIds => _myJoinedClassIds;
  LoadStatus get classesStatus => _classesStatus;
  LoadStatus get checkInsStatus => _checkInsStatus;
  String? get errorMessage => _errorMessage;

  bool get isLoadingClasses => _classesStatus == LoadStatus.loading;
  bool get isLoadingCheckIns => _checkInsStatus == LoadStatus.loading;

  /// Set of member IDs already checked in to the currently viewed class.
  Set<String> get checkedInMemberIds =>
      _currentCheckIns.map((c) => c.memberId).toSet();

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Subscribes to today's classes stream.
  ///
  /// Cancels any existing subscription first, so this method is idempotent and
  /// safe to call on pull-to-refresh. The UI transitions through
  /// [LoadStatus.loading] → [LoadStatus.loaded] (or [LoadStatus.error]).
  void watchTodaysClasses() {
    _classesStatus = LoadStatus.loading;
    notifyListeners();

    _classesSub?.cancel();
    _classesSub = _service.watchTodaysClasses().listen(
      (classes) {
        _todaysClasses = classes;
        _classesStatus = LoadStatus.loaded;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object e) {
        _classesStatus = LoadStatus.error;
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  /// Opens a real-time listener for [classId]'s attendees.
  ///
  /// Called from [ClassDetailScreen.initState] and on pull-to-refresh.
  /// Pass [keepExisting] = true (used by pull-to-refresh) to keep the current
  /// list visible while the stream reconnects, avoiding a blank-screen flash.
  /// The subscription is cancelled in [stopWatchingCheckIns] when the screen
  /// is disposed, preventing memory leaks and unnecessary Firestore reads.
  void watchCheckInsForClass(String classId, {bool keepExisting = false}) {
    _checkInsStatus = LoadStatus.loading;
    if (!keepExisting) _currentCheckIns = [];
    notifyListeners();

    _checkInsSub?.cancel();
    _checkInsSub = _service.watchCheckInsForClass(classId).listen(
      (checkIns) {
        _currentCheckIns = checkIns;
        _checkInsStatus = LoadStatus.loaded;
        notifyListeners();
      },
      onError: (Object e) {
        _checkInsStatus = LoadStatus.error;
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  /// Removes [ids] from the local list immediately (optimistic UI), then
  /// commits a single [WriteBatch] in the background — one network round-trip,
  /// one Firestore stream event, one list rebuild.
  ///
  /// On batch failure every removed item is restored atomically with a single
  /// [notifyListeners] call so the list snaps back without flickering.
  void optimisticRemoveIds(List<String> ids) {
    final idSet = ids.toSet();
    final toRemove =
        _currentCheckIns.where((c) => idSet.contains(c.id)).toList();
    if (toRemove.isEmpty) return;

    // Optimistic: remove all at once → exactly one rebuild.
    _currentCheckIns =
        _currentCheckIns.where((c) => !idSet.contains(c.id)).toList();
    notifyListeners();

    // Background: single batch for all deletes + one attendeeCount decrement.
    final classId = toRemove.first.classId;
    _service
        .bulkRemoveCheckIns(checkIns: toRemove, classId: classId)
        .catchError((_) {
      // Revert: restore every item at once → exactly one rebuild.
      final existingIds = _currentCheckIns.map((c) => c.id).toSet();
      final toRestore =
          toRemove.where((c) => !existingIds.contains(c.id)).toList();
      if (toRestore.isNotEmpty) {
        _currentCheckIns = [..._currentCheckIns, ...toRestore];
        notifyListeners();
      }
    });
  }

  void stopWatchingCheckIns() {
    _checkInsSub?.cancel();
    _checkInsSub = null;
    _currentCheckIns = [];
  }

  /// Subscribes to the stream of class IDs where [memberId] is checked in.
  /// Called when the user signs in; pass the `user:{uid}` memberId format.
  void watchMyCheckIns(String memberId) {
    _myCheckInsSub?.cancel();
    _myCheckInsSub = _service.watchUserCheckInClassIds(memberId).listen((ids) {
      _myJoinedClassIds = ids;
      notifyListeners();
    });
  }

  /// Cancels the personal check-in stream (called on sign-out).
  void stopWatchingMyCheckIns() {
    _myCheckInsSub?.cancel();
    _myCheckInsSub = null;
    _myJoinedClassIds = {};
    notifyListeners();
  }

  @override
  void dispose() {
    _classesSub?.cancel();
    _checkInsSub?.cancel();
    _myCheckInsSub?.cancel();
    super.dispose();
  }
}
