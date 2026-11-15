import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../core/theme/calm.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../shared/widgets/jom_button.dart';
import '../access/access.dart';
import 'backoffice_auth.dart';
import 'signin_screen.dart' show AuthCard;

/// The authenticator code every admin gives after the password. First time: set the authenticator up (QR code or secret).
class MfaScreen extends ConsumerStatefulWidget {
  const MfaScreen({super.key});

  @override
  ConsumerState<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends ConsumerState<MfaScreen> {
  final _code = TextEditingController();
  String? _factorId;
  TotpEnrollment? _enrolment;
  var _loading = true;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final auth = ref.read(backOfficeAuthProvider);
      final existing = await auth.verifiedFactorId();
      final enrolment = existing == null ? await auth.enrollTotp() : null;
      if (!mounted) return;
      setState(() {
        _factorId = existing ?? enrolment!.factorId;
        _enrolment = enrolment;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              "We couldn't start two-factor sign-in. Reload and try again.";
        });
      }
    }
  }

  Future<void> _verify() async {
    final id = _factorId;
    if (id == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(backOfficeAuthProvider).verifyTotp(id, _code.text.trim());
      ref.invalidate(adminAccessProvider);
    } on AuthException {
      _fail("That code isn't right. Check it and try again.");
    } catch (_) {
      _fail('Something went wrong. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String m) {
    if (mounted) setState(() => _error = m);
  }

  @override
  Widget build(BuildContext context) => AuthCard(
    cardKey: 'bo-mfa',
    children: [
      const Text(
        'Two-factor code',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      if (_loading)
        const Center(child: CircularProgressIndicator())
      else ...[
        if (_enrolment != null) ...[
          const Text(
            'Scan this with an authenticator app (Google Authenticator, 1Password, Authy), then type the 6 digit code it shows.',
            style: TextStyle(color: Calm.mut),
          ),
          const SizedBox(height: 12),
          Center(child: QrImageView(data: _enrolment!.uri, size: 180)),
          const SizedBox(height: 8),
          const Text(
            "Can't scan? Type this secret into the app:",
            style: TextStyle(color: Calm.mut, fontSize: 13),
          ),
          SelectableText(
            _enrolment!.secret,
            key: const Key('bo-mfa-secret'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
          ),
        ] else
          const Text(
            'Enter the 6 digit code from your authenticator app.',
            style: TextStyle(color: Calm.mut),
          ),
        const SizedBox(height: 12),
        if (_factorId != null) ...[
          TextField(
            key: const Key('bo-mfa-code'),
            controller: _code,
            keyboardType: TextInputType.number,
            autofocus: true,
            onSubmitted: (_) => _verify(),
            decoration: const InputDecoration(
              labelText: 'Code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: const Key('bo-mfa-verify'),
            child: JomButton(label: 'Verify', busy: _busy, onPressed: _verify),
          ),
        ],
      ],
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Calm.bad)),
      ],
      TextButton(
        key: const Key('bo-signout'),
        onPressed: () => ref.read(authRepositoryProvider).signOut(),
        child: const Text('Sign out'),
      ),
    ],
  );
}
