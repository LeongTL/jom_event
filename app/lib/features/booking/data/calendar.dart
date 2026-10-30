import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../event/domain/event_detail.dart';

/// Adds an event to the phone's calendar. Tests replace it with a recorder.
final addToCalendarProvider = Provider<Future<bool> Function(EventDetail)>(
  (ref) =>
      (d) => Add2Calendar.addEvent2Cal(
        Event(
          title: d.summary.title,
          location: d.venue ?? d.summary.area,
          startDate: d.summary.startsAt,
          endDate: d.summary.endsAt,
        ),
      ),
);
