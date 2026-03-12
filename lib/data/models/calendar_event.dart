class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.isAllDay = false,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final startMap = json['start'] as Map<String, dynamic>;
    final endMap = json['end'] as Map<String, dynamic>;
    final isAllDay =
        startMap.containsKey('date') && !startMap.containsKey('dateTime');

    DateTime parseTime(Map<String, dynamic> map) {
      final raw = (map['dateTime'] ?? map['date']) as String;
      return DateTime.parse(raw).toLocal();
    }

    return CalendarEvent(
      id: json['id'] as String,
      title: (json['summary'] as String?) ?? '(no title)',
      start: parseTime(startMap),
      end: parseTime(endMap),
      isAllDay: isAllDay,
    );
  }
}
