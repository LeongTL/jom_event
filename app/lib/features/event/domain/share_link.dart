/// The link a host sends for an event: opens the app on the event (the platform scheme `jom`). The https link with
/// a landing page for people without the app comes with the sharing work and replaces this.
String shareLink(String code) => 'jom://e/$code';
