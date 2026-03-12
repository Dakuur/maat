import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/calendar_event.dart';
import '../../data/models/fitness_class.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/calendar_service.dart';
import '../../data/services/firebase_service.dart';

class CalendarProvider extends ChangeNotifier {
  DateTime _selectedDay = _today();
  List<FitnessClass> _classes = [];
  Set<String> _myJoinedClassIds = {};
  StreamSubscription<Set<String>>? _myCheckInsSub;
  bool _loadingClasses = false;
  bool _syncing = false;
  String? _syncError;

  // Events cached by date key ("yyyy-MM-dd") — persists across day navigation.
  // One sync call fetches ±7 days so the user never needs to re-sync just
  // because they tapped the next/previous arrow.
  final Map<String, List<CalendarEvent>> _eventCache = {};

  DateTime get selectedDay => _selectedDay;
  List<FitnessClass> get classes => _classes;
  bool get loadingClasses => _loadingClasses;
  bool get syncing => _syncing;
  String? get syncError => _syncError;

  /// Events for the currently selected day, served from cache.
  List<CalendarEvent> get calendarEvents =>
      _eventCache[_dateKey(_selectedDay)] ?? [];

  /// True once at least one successful sync has populated the cache.
  bool get calendarConnected => _eventCache.isNotEmpty;

  /// Total number of cached events across all days (shown in the sync bar).
  int get cachedEventCount =>
      _eventCache.values.fold(0, (sum, list) => sum + list.length);

  /// Class IDs where the signed-in user is personally enrolled.
  Set<String> get myJoinedClassIds => _myJoinedClassIds;

  /// Class IDs that overlap with at least one Google Calendar event for the
  /// selected day.
  Set<String> get conflictClassIds {
    final events = calendarEvents;
    if (events.isEmpty) return const {};
    final result = <String>{};
    for (final cls in _classes) {
      for (final ev in events) {
        if (cls.startTime.isBefore(ev.end) && cls.endTime.isAfter(ev.start)) {
          result.add(cls.id);
          break;
        }
      }
    }
    return result;
  }

  CalendarProvider() {
    _fetchClasses();
  }

  // ── Day navigation ─────────────────────────────────────────────────────────
  // The event cache is NOT cleared on navigation — cached days remain available
  // instantly without re-syncing.

  void goToPreviousDay() {
    _selectedDay = _selectedDay.subtract(const Duration(days: 1));
    _fetchClasses();
  }

  void goToNextDay() {
    _selectedDay = _selectedDay.add(const Duration(days: 1));
    _fetchClasses();
  }

  void goToToday() {
    _selectedDay = _today();
    _fetchClasses();
  }

  // ── Classes ────────────────────────────────────────────────────────────────

  /// Re-fetches classes for the current day without clearing the event cache.
  /// Called each time the CalendarScreen is opened.
  Future<void> refreshCurrentDay() => _fetchClasses();

  Future<void> _fetchClasses() async {
    _loadingClasses = true;
    notifyListeners();
    try {
      _classes = await FirebaseService.instance.fetchClassesForDay(_selectedDay);
    } catch (_) {
      _classes = [];
    } finally {
      _loadingClasses = false;
      notifyListeners();
    }
  }

  // ── Google Calendar sync ───────────────────────────────────────────────────

  /// Syncs a 15-day window (±7 days from the selected day) in a single API
  /// call, then caches results by day. Subsequent day navigation uses the
  /// cache and never needs another sync unless the user explicitly requests it.
  Future<void> syncWithGoogleCalendar() async {
    _syncing = true;
    _syncError = null;
    notifyListeners();
    try {
      final token = await AuthService.instance.requestCalendarAccessToken();
      if (token == null) {
        _syncError = 'Calendar access denied.';
        return;
      }

      // Fetch a wide window so adjacent days are already cached.
      final rangeStart = _selectedDay.subtract(const Duration(days: 7));
      final rangeEnd = _selectedDay.add(const Duration(days: 8));

      final events = await CalendarService.instance.fetchEventsForRange(
        token,
        rangeStart,
        rangeEnd,
      );

      // Rebuild the cache for the fetched range (keeps data outside the
      // range untouched in case the user has synced a different window before).
      for (final e in events) {
        final key = _dateKey(e.start);
        _eventCache.putIfAbsent(key, () => []).add(e);
      }

      // Ensure every day in the range has an entry (even if empty) so
      // calendarConnected returns true even for days with no events.
      var cursor = DateTime(_selectedDay.year, _selectedDay.month,
          _selectedDay.day - 7);
      for (int i = 0; i < 15; i++) {
        _eventCache.putIfAbsent(_dateKey(cursor), () => []);
        cursor = cursor.add(const Duration(days: 1));
      }
    } catch (e) {
      _syncError = 'Could not sync calendar. Try again.';
      debugPrint('CalendarProvider sync error: $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Call when the user signs in/out. [memberId] is `user:{uid}` or null.
  /// On sign-out (null) the Google Calendar event cache is also cleared so
  /// sync data from the previous session is not shown on the next account.
  void setUserMemberId(String? memberId) {
    _myCheckInsSub?.cancel();
    if (memberId == null) {
      _myJoinedClassIds = {};
      _eventCache.clear();
      _syncError = null;
      notifyListeners();
      return;
    }
    _myCheckInsSub =
        FirebaseService.instance.watchUserCheckInClassIds(memberId).listen(
      (ids) {
        _myJoinedClassIds = ids;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _myCheckInsSub?.cancel();
    super.dispose();
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}
