import 'package:flutter/foundation.dart';

import '../../data/models/fitness_class.dart';
import '../../data/models/member.dart';
import '../../data/services/firebase_service.dart';

enum CheckInState { idle, loading, success, error, alreadyCheckedIn }

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

  Future<void> loadMembers() async {
    if (_membersLoaded) return;
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

  /// Resets ephemeral check-in state so the kiosk is ready for the next user.
  void reset() {
    _state = CheckInState.idle;
    _selectedMember = null;
    _errorMessage = null;
    notifyListeners();
  }
}
