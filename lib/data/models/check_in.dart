import 'package:cloud_firestore/cloud_firestore.dart';

enum CheckInStatus {
  confirmed,
  registered;

  String get label => switch (this) {
        CheckInStatus.confirmed => 'Confirmed',
        CheckInStatus.registered => 'Registered',
      };
}

class CheckIn {
  const CheckIn({
    required this.id,
    required this.memberId,
    required this.classId,
    required this.memberName,
    this.memberProfilePicture,
    required this.checkedInAt,
    required this.status,
  });

  final String id;
  final String memberId;
  final String classId;
  final String memberName;
  final String? memberProfilePicture;
  final DateTime checkedInAt;
  final CheckInStatus status;

  factory CheckIn.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return CheckIn(
      id: doc.id,
      memberId: d['memberId'] as String? ?? '',
      classId: d['classId'] as String? ?? '',
      memberName: d['memberName'] as String? ?? '',
      memberProfilePicture: d['memberProfilePicture'] as String?,
      checkedInAt: (d['checkedInAt'] as Timestamp).toDate(),
      status: CheckInStatus.values.firstWhere(
        (s) => s.name == (d['status'] as String? ?? 'registered'),
        orElse: () => CheckInStatus.registered,
      ),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'memberId': memberId,
        'classId': classId,
        'memberName': memberName,
        if (memberProfilePicture != null)
          'memberProfilePicture': memberProfilePicture,
        'checkedInAt': Timestamp.fromDate(checkedInAt),
        'status': status.name,
      };
}
