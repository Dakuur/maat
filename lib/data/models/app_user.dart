import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.trainingPlan,
  });

  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final String? trainingPlan;

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppUser(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String?,
      trainingPlan: data['trainingPlan'] as String?,
    );
  }

  AppUser copyWith({String? trainingPlan}) => AppUser(
        uid: uid,
        displayName: displayName,
        email: email,
        photoUrl: photoUrl,
        trainingPlan: trainingPlan ?? this.trainingPlan,
      );
}
