import 'package:flutter/foundation.dart';

import '../../data/models/fitness_class.dart';
import '../../data/models/member.dart';
import '../../data/services/firebase_service.dart';

/// Represents the result of a check-in submission attempt.
enum CheckInState { idle, loading, success, error, alreadyCheckedIn }

/// Manages the member search list and the check-in submission flow.
///
/// Responsibilities:
/// - Loads and caches the full member list (loaded once, refreshed on demand).
/// - Filters members client-side for instant search without Firestore queries.
/// - Holds the selected member + class pair while the user navigates the
///   confirmation flow.
/// - Submits single and bulk check-ins via [FirebaseService] and surfaces the
///   result through [CheckInState].
///
/// Kiosk reset: [reset] clears ephemeral selection state without touching the
/// member list, so the next user gets a clean slate without a network round-trip.
class CheckInProvider extends ChangeNotifier {
  CheckInProvider(this._service);

  final FirebaseService _service;

  // ── State ─────────────────────────────────────────────────────────────────
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  Member? _selectedMember;
  FitnessClass? _selectedClass;
  CheckInState _state = CheckInState.idle;
  String? _errorMessage;
  bool _membersLoaded = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<Member> get filteredMembers => _filteredMembers;
  Member? get selectedMember => _selectedMember;
  FitnessClass? get selectedClass => _selectedClass;
  CheckInState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get membersLoaded => _membersLoaded;

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Loads all members from Firestore into the local cache.
  ///
  /// Short-circuits if members are already loaded, unless [force] is `true`
  /// (used by pull-to-refresh). Results are stored in [_allMembers] and
  /// [_filteredMembers] is reset to the full list.
  Future<void> loadMembers({bool force = false}) async {
    if (_membersLoaded && !force) return;
    if (force) {
      _membersLoaded = false;
      notifyListeners();
    }
    try {
      _allMembers = await _service.getMembers();
      _filteredMembers = List.from(_allMembers);
      _membersLoaded = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Filters the cached member list by [query] (first name, last name, or full
  /// name match). Called on every keystroke — operates purely in-memory so
  /// there is no Firestore cost and no perceptible latency.
  void filterMembers(String query) {
    final q = query.trim().toLowerCase();
    _filteredMembers = q.isEmpty
        ? List.from(_allMembers)
        : _allMembers
            .where((m) =>
                m.firstName.toLowerCase().contains(q) ||
                m.lastName.toLowerCase().contains(q) ||
                m.fullName.toLowerCase().contains(q))
            .toList();
    notifyListeners();
  }

  void selectMember(Member member) {
    _selectedMember = member;
    _state = CheckInState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  void selectClass(FitnessClass fc) {
    _selectedClass = fc;
    notifyListeners();
  }

  Future<void> submitCheckIn() async {
    if (_selectedMember == null || _selectedClass == null) return;

    _state = CheckInState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.checkInMember(
        memberId: _selectedMember!.id,
        classId: _selectedClass!.id,
        memberName: _selectedMember!.fullName,
        memberProfilePicture: _selectedMember!.profilePicture,
      );
      _state = CheckInState.success;
    } on AlreadyCheckedInException {
      _state = CheckInState.alreadyCheckedIn;
    } catch (e) {
      _state = CheckInState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Checks in multiple members to the same class in sequence.
  ///
  /// Returns a map of memberId → result string:
  ///   'ok' | 'already_checked_in' | error message
  Future<Map<String, String>> bulkCheckIn({
    required List<Member> members,
    required FitnessClass fitnessClass,
  }) async {
    _state = CheckInState.loading;
    notifyListeners();

    final results = <String, String>{};
    for (final member in members) {
      try {
        await _service.checkInMember(
          memberId: member.id,
          classId: fitnessClass.id,
          memberName: member.fullName,
          memberProfilePicture: member.profilePicture,
        );
        results[member.id] = 'ok';
      } on AlreadyCheckedInException {
        results[member.id] = 'already_checked_in';
      } catch (e) {
        results[member.id] = e.toString();
      }
    }

    _state = CheckInState.idle;
    notifyListeners();
    return results;
  }

  /// Resets ephemeral check-in state so the kiosk is ready for the next user.
  void reset() {
    _state = CheckInState.idle;
    _selectedMember = null;
    _errorMessage = null;
    notifyListeners();
  }
}
