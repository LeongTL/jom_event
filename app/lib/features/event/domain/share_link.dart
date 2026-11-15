import 'event_labels.dart';

String _trim(String base) => base.replaceAll(RegExp(r'/+$'), '');

/// The link for an event: `<SHARE_BASE_URL>/e/<code>`. With no base set (the domain is not bought yet) it is the
/// app's own link `jom://e/<code>`, which only opens on a phone that has the app.
String eventLink(String base, String code) =>
    base.isEmpty ? 'jom://e/$code' : '${_trim(base)}/e/$code';

/// The link for a person or a host: `<SHARE_BASE_URL>/u/<username>`.
String personLink(String base, String username) =>
    base.isEmpty ? 'jom://u/$username' : '${_trim(base)}/u/$username';

/// "Title · Sat 12 Jan · 6:00 PM · Area", leaving out what is missing.
String eventShareText(String title, DateTime? startsAt, String? area) => [
  title,
  if (startsAt != null) fullWhen(startsAt),
  if (area != null && area.isNotEmpty) area,
].join(' · ');

String personShareText(String name, String username) => '$name · @$username';

/// What the share sheet sends: the text, then the link on its own line.
String shareMessage(String text, String link) => '$text\n$link';
