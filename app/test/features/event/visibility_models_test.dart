import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/event/domain/event_detail.dart';
import 'package:jom/features/host/domain/event_form_state.dart';
import 'package:jom/features/host/domain/host.dart';

const _detail = {
  'event_id': 'e1',
  'host_id': 'h1',
  'host_name': 'Mei Studio',
  'rating_avg': null,
  'rating_count': 0,
  'title': 'Secret class',
  'description': null,
  'venue': 'Deck 5',
  'glyph': '🎉',
  'color_a': '#11998e',
  'color_b': '#38ef7d',
  'starts_at': '2030-01-12T01:00:00+00:00',
  'ends_at': '2030-01-12T03:00:00+00:00',
  'price_sen': 3000,
  'area': 'Bangsar',
  'lat': 3.129,
  'lng': 101.671,
  'distance_km': null,
  'is_live': false,
  'is_ended': false,
  'spots_left': 5,
  'categories': ['make'],
  'cancel_policy': '24h',
  'source_url': null,
  'is_bookable': true,
  'poster_url': null,
  'going': 0,
  'host_verified': false,
  'host_event_count': 1,
};

const _hostRow = {
  'id': 'e1',
  'title': 'Free walk',
  'description': null,
  'categories': ['move'],
  'area': 'Bangsar',
  'venue': 'Park',
  'starts_at': '2030-01-12T01:00:00+00:00',
  'ends_at': '2030-01-12T03:00:00+00:00',
  'capacity': 10,
  'price_sen': 0,
  'cancel_policy': '24h',
  'accept_bookings': true,
  'status': 'published',
  'seats_sold': 0,
  'saves': 7,
  'visibility': 'private',
  'share_code': 'abCD12efGH',
};

void main() {
  test('an event page knows when the event is private', () {
    expect(
      EventDetail.fromJson({..._detail, 'visibility': 'private'}).isPrivate,
      isTrue,
    );
    expect(
      EventDetail.fromJson({..._detail, 'visibility': 'public'}).isPrivate,
      isFalse,
    );
  });

  test('a host row carries saves, visibility and the share code', () {
    final r = HostEventRow.fromJson(_hostRow);
    expect(r.saves, 7);
    expect(r.isPrivate, isTrue);
    expect(r.shareCode, 'abCD12efGH');
    final paid = HostEventRow.fromJson({
      ..._hostRow,
      'saves': null,
      'visibility': 'public',
    });
    expect(paid.saves, isNull);
    expect(paid.isPrivate, isFalse);
  });

  test('the form keeps visibility from the row and sends it', () {
    final f = EventForm.fromRow(HostEventRow.fromJson(_hostRow));
    expect(f.isPrivate, isTrue);
    expect(f.toPayload(null)['visibility'], 'private');
    expect(
      f.copyWith(isPrivate: false).toPayload(null)['visibility'],
      'public',
    );
    expect(const EventForm().isPrivate, isFalse);
  });
}
