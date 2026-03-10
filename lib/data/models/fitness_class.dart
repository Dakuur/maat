import 'package:cloud_firestore/cloud_firestore.dart';

class FitnessClass {
  const FitnessClass({
    required this.id,
    required this.name,
    required this.instructor,
    required this.startTime,
    required this.endTime,
    required this.tags,
    required this.maxCapacity,
    required this.attendeeCount,
  });

  final String id;
  final String name;
  final String instructor;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> tags;
  final int maxCapacity;
  final int attendeeCount;

  bool get isFull => attendeeCount >= maxCapacity;

  factory FitnessClass.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return FitnessClass(
      id: doc.id,
      name: d['name'] as String? ?? '',
      instructor: d['instructor'] as String? ?? '',
      startTime: (d['startTime'] as Timestamp).toDate(),
      endTime: (d['endTime'] as Timestamp).toDate(),
      tags: List<String>.from(d['tags'] as List? ?? []),
      maxCapacity: d['maxCapacity'] as int? ?? 20,
      attendeeCount: d['attendeeCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'instructor': instructor,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'tags': tags,
        'maxCapacity': maxCapacity,
        'attendeeCount': attendeeCount,
      };

  FitnessClass copyWith({int? attendeeCount}) => FitnessClass(
        id: id,
        name: name,
        instructor: instructor,
        startTime: startTime,
        endTime: endTime,
        tags: tags,
        maxCapacity: maxCapacity,
        attendeeCount: attendeeCount ?? this.attendeeCount,
      );
}
