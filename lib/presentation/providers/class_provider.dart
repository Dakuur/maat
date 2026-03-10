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
/// - Delegates mutations (remove check-in) back to [FirebaseService].
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
  LoadStatus _classesStatus = LoadStatus.initial;
  LoadStatus _checkInsStatus = LoadStatus.initial;
  String? _errorMessage;

  StreamSubscription<List<FitnessClass>>? _classesSub;
  StreamSubscription<List<CheckIn>>? _checkInsSub;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<FitnessClass> get todaysClasses => _todaysClasses;
  List<CheckIn> get currentCheckIns => _currentCheckIns;
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
  /// Called from [ClassDetailScreen.initState]. The subscription is cancelled
  /// in [stopWatchingCheckIns] when the screen is disposed, preventing memory
  /// leaks and unnecessary Firestore reads.
  void watchCheckInsForClass(String classId) {
    _checkInsStatus = LoadStatus.loading;
    _currentCheckIns = [];
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

  Future<void> removeCheckIn({
    required String checkInId,
    required String classId,
  }) async {
    await _service.removeCheckIn(checkInId: checkInId, classId: classId);
  }

  void stopWatchingCheckIns() {
    _checkInsSub?.cancel();
    _checkInsSub = null;
    _currentCheckIns = [];
  }

  @override
  void dispose() {
    _classesSub?.cancel();
    _checkInsSub?.cancel();
    super.dispose();
  }
}
