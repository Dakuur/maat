import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/calendar_event.dart';

class CalendarService {
  CalendarService._();
  static final CalendarService instance = CalendarService._();

  static const _base = 'https://www.googleapis.com/calendar/v3';

  /// Fetches all timed events from the primary calendar between [rangeStart]
  /// and [rangeEnd] (exclusive). One network call covers multiple days so the
  /// provider can cache them and avoid re-syncing when the user navigates.
  Future<List<CalendarEvent>> fetchEventsForRange(
    String accessToken,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async {
    final uri = Uri.parse('$_base/calendars/primary/events').replace(
      queryParameters: {
        'timeMin': rangeStart.toUtc().toIso8601String(),
        'timeMax': rangeEnd.toUtc().toIso8601String(),
        'singleEvents': 'true',
        'orderBy': 'startTime',
        'maxResults': '250',
      },
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Calendar API ${response.statusCode}: ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .where((e) => !e.isAllDay)
        .toList();
  }
}
