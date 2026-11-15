import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/event/domain/share_link.dart';

void main() {
  const base = 'https://share.example.invalid';

  group('links', () {
    test('an event link and a person link', () {
      expect(eventLink(base, 'abCD12efGH'), '$base/e/abCD12efGH');
      expect(personLink(base, 'meihost'), '$base/u/meihost');
    });

    test('a trailing slash on the base does not double up', () {
      expect(eventLink('$base/', 'abCD12efGH'), '$base/e/abCD12efGH');
      expect(personLink('$base//', 'meihost'), '$base/u/meihost');
    });

    test('with no base set the link falls back to the app scheme', () {
      expect(eventLink('', 'abCD12efGH'), 'jom://e/abCD12efGH');
      expect(personLink('', 'meihost'), 'jom://u/meihost');
    });
  });

  group('the text next to the link', () {
    // 12 Jan 2030 10:00 UTC is Sat 12 Jan, 6:00 PM in Kuala Lumpur
    final starts = DateTime.utc(2030, 1, 12, 10);

    test('an event: title, date and time, area', () {
      expect(
        eventShareText('Sunset yoga', starts, 'Bangsar'),
        'Sunset yoga · Sat 12 Jan · 6:00 PM · Bangsar',
      );
    });

    test('a missing date or area is left out, not printed as null', () {
      expect(eventShareText('Sunset yoga', null, null), 'Sunset yoga');
      expect(
        eventShareText('Sunset yoga', starts, null),
        'Sunset yoga · Sat 12 Jan · 6:00 PM',
      );
    });

    test('a person: name and @username', () {
      expect(personShareText('Mei Studio', 'meihost'), 'Mei Studio · @meihost');
    });

    test('the sent message is the text, a line break and the link', () {
      expect(
        shareMessage('Sunset yoga · Bangsar', '$base/e/abc'),
        'Sunset yoga · Bangsar\n$base/e/abc',
      );
    });
  });
}
