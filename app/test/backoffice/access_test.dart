import 'package:flutter_test/flutter_test.dart';
import 'package:jom/backoffice/access/access.dart';

Shell decide({
  bool signedIn = true,
  bool isAdmin = false,
  bool aal2 = false,
  String host = 'none',
  Shell? chosen,
}) => decideShell(
  signedIn: signedIn,
  isAdmin: isAdmin,
  aal2: aal2,
  hostStatus: host,
  chosen: chosen,
);

void main() {
  test('signed_out_goes_to_sign_in', () {
    expect(decide(signedIn: false), Shell.signIn);
    expect(decide(signedIn: false, isAdmin: true, aal2: true), Shell.signIn);
  });

  test('a_plain_user_is_not_authorised', () {
    expect(decide(), Shell.notAuthorised);
  });

  test('a_pending_rejected_or_suspended_host_is_not_authorised', () {
    for (final s in ['pending', 'rejected', 'suspended']) {
      expect(decide(host: s), Shell.notAuthorised, reason: s);
    }
  });

  test('an_approved_host_gets_the_host_shell', () {
    expect(decide(host: 'approved'), Shell.host);
  });

  test('an_admin_with_a_password_only_must_give_the_code_first', () {
    expect(decide(isAdmin: true), Shell.mfa);
    expect(decide(isAdmin: true, host: 'approved'), Shell.mfa);
    expect(
      decide(isAdmin: true, host: 'approved', chosen: Shell.host),
      Shell.mfa,
      reason: 'a remembered host choice cannot skip the code',
    );
  });

  test('an_admin_with_two_factor_gets_the_admin_shell', () {
    expect(decide(isAdmin: true, aal2: true), Shell.admin);
  });

  test('an_admin_who_is_also_a_host_can_switch_and_defaults_to_admin', () {
    expect(decide(isAdmin: true, aal2: true, host: 'approved'), Shell.admin);
    expect(
      decide(isAdmin: true, aal2: true, host: 'approved', chosen: Shell.host),
      Shell.host,
    );
  });

  test(
    'a_choice_of_host_is_ignored_when_the_person_is_not_an_approved_host',
    () {
      expect(
        decide(
          isAdmin: true,
          aal2: true,
          host: 'suspended',
          chosen: Shell.host,
        ),
        Shell.admin,
      );
    },
  );

  test('two_factor_alone_does_not_make_an_admin', () {
    expect(decide(aal2: true), Shell.notAuthorised);
  });
}
