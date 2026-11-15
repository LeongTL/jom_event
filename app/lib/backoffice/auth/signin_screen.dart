import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../core/theme/calm.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/phone_number.dart';
import '../../shared/widgets/jom_button.dart';
import 'backoffice_auth.dart';

/// A centred card for the sign-in steps; the same on every width.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.cardKey, required this.children});
  final String cardKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Calm.bg,
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            key: Key(cardKey),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Calm.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Calm.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Calm.acc,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Text(
                        'J',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: Calm.serif,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Jom back office',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: Calm.serif,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

enum _Tab { host, admin }

enum _Step { phone, code }

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  var _tab = _Tab.host;
  var _step = _Step.phone;
  var _busy = false;
  String? _error;
  String _phone = '';
  final _phoneField = TextEditingController();
  final _codeField = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    for (final c in [_phoneField, _codeField, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  Future<void> _sendCode() => _run(() async {
    final String e164;
    try {
      e164 = normalizeMyPhone(_phoneField.text);
    } on FormatException catch (e) {
      return _fail(e.message);
    }
    try {
      await ref.read(authRepositoryProvider).sendOtp(e164);
    } catch (_) {
      return _fail("We couldn't send the code. Wait a moment and try again.");
    }
    if (mounted) {
      setState(() {
        _phone = e164;
        _step = _Step.code;
      });
    }
  });

  Future<void> _verify() => _run(() async {
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyOtp(_phone, _codeField.text.trim());
    } on AuthException {
      _fail("That code isn't right. Check it and try again.");
    } catch (_) {
      _fail('Something went wrong. Check your connection and try again.');
    }
  });

  Future<void> _google() => _run(() async {
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on GoogleCancelled {
      // closed the window: stay here
    } catch (_) {
      _fail('Google sign-in went wrong. Try again, or use your phone number.');
    }
  });

  Future<void> _password_() => _run(() async {
    try {
      await ref
          .read(backOfficeAuthProvider)
          .signInWithPassword(_email.text.trim(), _password.text);
    } on AuthException {
      _fail('Wrong email or password.');
    } catch (_) {
      _fail('Something went wrong. Check your connection and try again.');
    }
  });

  Widget _tabButton(_Tab tab, String label) => Expanded(
    child: GestureDetector(
      key: Key('bo-tab-${tab.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _tab = tab;
        _error = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _tab == tab ? Calm.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _tab == tab ? Calm.ink : Calm.mut,
          ),
        ),
      ),
    ),
  );

  Widget _hostForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_step == _Step.phone) ...[
        TextField(
          key: const Key('bo-phone'),
          controller: _phoneField,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Mobile number',
            hintText: '012 345 6789',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('bo-send-code'),
          child: JomButton(
            label: 'Send code',
            busy: _busy,
            onPressed: _sendCode,
          ),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('bo-google'),
          child: JomButton(
            label: 'Continue with Google',
            primary: false,
            onPressed: _google,
          ),
        ),
      ] else ...[
        Text(
          'We sent a 6 digit code to ${prettyMyPhone(_phone)}',
          style: const TextStyle(color: Calm.mut),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('bo-code'),
          controller: _codeField,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Code',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('bo-verify'),
          child: JomButton(label: 'Verify', busy: _busy, onPressed: _verify),
        ),
        TextButton(
          onPressed: () => setState(() {
            _step = _Step.phone;
            _error = null;
          }),
          child: const Text('Use a different number'),
        ),
      ],
    ],
  );

  Widget _adminForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const Key('bo-email'),
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.username],
        decoration: const InputDecoration(
          labelText: 'Email',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('bo-password'),
        controller: _password,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) => _password_(),
        decoration: const InputDecoration(
          labelText: 'Password',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      KeyedSubtree(
        key: const Key('bo-signin-submit'),
        child: JomButton(label: 'Continue', busy: _busy, onPressed: _password_),
      ),
      const SizedBox(height: 8),
      const Text(
        'You will be asked for the code from your authenticator app next.',
        style: TextStyle(color: Calm.mut, fontSize: 13),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AuthCard(
    cardKey: 'bo-signin',
    children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Calm.chip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _tabButton(_Tab.host, 'Host'),
            _tabButton(_Tab.admin, 'Admin'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (_tab == _Tab.host) _hostForm() else _adminForm(),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Calm.bad)),
      ],
    ],
  );
}
