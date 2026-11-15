import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/router/app_router.dart';

void main() {
  test('a jom:// link becomes the in-app path', () {
    expect(deepLinkRedirect(Uri.parse('jom://e/abCD12efGH')), '/e/abCD12efGH');
    expect(deepLinkRedirect(Uri.parse('jom://e/abCD12efGH/')), '/e/abCD12efGH');
  });

  test('a jom://u link becomes the person path', () {
    expect(deepLinkRedirect(Uri.parse('jom://u/meihost')), '/u/meihost');
  });

  test('an https share link reaches the app as its path and is left alone', () {
    // the platform hands the app only the path of https://<domain>/e/<code>
    expect(deepLinkRedirect(Uri.parse('/u/meihost')), isNull);
  });

  test('in-app paths are left alone', () {
    expect(deepLinkRedirect(Uri.parse('/event/e1')), isNull);
    expect(deepLinkRedirect(Uri.parse('/e/abCD12efGH')), isNull);
  });
}
