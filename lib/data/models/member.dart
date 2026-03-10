import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  const Member({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    this.plan,
    this.memberSince,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final String? plan;
  final String? memberSince;

  String get fullName => '$firstName $lastName';

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  factory Member.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Member(
      id: doc.id,
      firstName: d['firstName'] as String? ?? '',
      lastName: d['lastName'] as String? ?? '',
      profilePicture: d['profilePicture'] as String?,
      plan: d['plan'] as String?,
      memberSince: d['memberSince'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'firstName': firstName,
        'lastName': lastName,
        if (profilePicture != null) 'profilePicture': profilePicture,
        if (plan != null) 'plan': plan,
        if (memberSince != null) 'memberSince': memberSince,
      };
}
