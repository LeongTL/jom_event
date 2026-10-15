@Tags(['staging'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// The real SupabaseAuthRepository against the staging project, with the test phone number
// (+60123456789 = 123456, set up in the Supabase dashboard). It leaves the test account as it found it.
const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');
const _phone = '+60123456789';

void main() {
  late SupabaseClient client;
  late SupabaseAuthRepository repo;

  setUp(() {
    client = SupabaseClient(_url, _key);
    repo = SupabaseAuthRepository(client);
  });
  tearDown(() => client.dispose());

  test('the test number signs in, a name is saved on the account and the profile, and signing out works', () async {
    expect(_url, isNotEmpty, reason: 'run with --dart-define-from-file=env/staging.json');

    // signed out to begin with: the stream's first event is "nobody"
    expect(await repo.session.first, isNull);

    await repo.sendOtp(_phone);
    await repo.verifyOtp(_phone, '123456');
    final session = await repo.session.first;
    expect(session, isNotNull);
    expect(session!.user.phone, '60123456789');

    // the account may already have a name from earlier use; remember it so the test can put it back
    final before = (session.user.userMetadata ?? const {})['full_name'];

    await repo.setName('Staging Test');
    final profile = await client.schema('identity').from('profiles').select('name, phone').single();
    expect(profile['name'], 'Staging Test');
    expect(profile['phone'], '60123456789');
    expect((client.auth.currentUser!.userMetadata ?? const {})['full_name'], 'Staging Test');

    // put the account back as it was, so the next real sign-in still shows the "what should we call you?" step
    await client.auth.updateUser(UserAttributes(data: {'full_name': before}));
    await client.schema('identity').rpc('update_profile', params: {'name': before, 'phone': '60123456789'});
    final restored = await client.schema('identity').from('profiles').select('name').single();
    expect(restored['name'], before);

    await repo.signOut();
    expect(await repo.session.first, isNull);
  });

  test('a wrong code is refused by the real backend', () async {
    await Future<void>.delayed(const Duration(seconds: 4)); // Supabase allows one text per number every 3 seconds
    await repo.sendOtp(_phone);
    await expectLater(repo.verifyOtp(_phone, '000000'), throwsA(isA<AuthException>()));
    expect(await repo.session.first, isNull);
  });

  test('a number that is not on the test list does not get a working code', () async {
    // phone sign-in with the dummy SMS provider cannot send a real text: it must fail, not pretend
    await expectLater(repo.sendOtp('+60198765432'), throwsA(anything));
  });
}
