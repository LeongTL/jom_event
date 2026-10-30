import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../data/auth_repository.dart';
import '../domain/auth_gate.dart';
import '../domain/phone_number.dart';
import 'name_screen.dart';
import 'otp_screen.dart';
import 'phone_screen.dart';

/// Opens the sign-in sheet. Completes with true once the user is signed in, null or false if they close it.
Future<bool?> showSignInSheet(
  BuildContext context, {
  AuthReason? reason,
  bool startWithPhone = false,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => SignInSheet(reason: reason, startWithPhone: startWithPhone),
);

/// Wording from the prototype's sign-in modal.
const _copy = {
  AuthReason.join: (
    'Sign in to join',
    'Free or paid, we need to know who is coming. Browsing stays open.',
  ),
  AuthReason.save: (
    'Sign in to save',
    'Saved events live in your account, so they follow you across phones.',
  ),
  AuthReason.chat: (
    'Sign in to chat',
    'Chat is between you and the host, so we need to know who you are.',
  ),
};

enum _Step { choose, phone, otp, name }

class SignInSheet extends ConsumerStatefulWidget {
  const SignInSheet({super.key, this.reason, this.startWithPhone = false});

  /// Null for the plain "Sign in" opened from a signed-out tab.
  final AuthReason? reason;
  final bool startWithPhone;

  @override
  ConsumerState<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends ConsumerState<SignInSheet> {
  late _Step _step = widget.startWithPhone ? _Step.phone : _Step.choose;
  final _phoneField = TextEditingController();
  final _otpField = TextEditingController();
  final _nameField = TextEditingController();
  String _phone = ''; // +60..., once a code has been sent
  String? _error;
  bool _busy = false;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  void dispose() {
    _phoneField.dispose();
    _otpField.dispose();
    _nameField.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  /// Signed in: ask for a name if the account has none, otherwise we are done.
  Future<void> _afterSignIn() async {
    final session = await _repo.session
        .firstWhere((s) => s != null)
        .timeout(const Duration(seconds: 10));
    if (!mounted) return;
    if (needsName(session!)) {
      setState(() => _step = _Step.name);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _google() => _run(() async {
    try {
      await _repo.signInWithGoogle();
      await _afterSignIn();
    } on GoogleCancelled {
      // the person closed the Google window: stay where we are
    } on GoogleNotConfigured {
      _fail(
        "Google sign-in isn't set up on this device yet. Use your phone number instead.",
      );
    } catch (_) {
      _fail('Google sign-in went wrong. Try again, or use your phone number.');
    }
  });

  Future<void> _sendCode() => _run(() async {
    final String e164;
    try {
      e164 = normalizeMyPhone(_phoneField.text);
    } on FormatException catch (e) {
      return _fail(e.message);
    }
    try {
      await _repo.sendOtp(e164);
    } catch (_) {
      return _fail("We couldn't send the code. Wait a moment and try again.");
    }
    if (mounted) {
      setState(() {
        _phone = e164;
        _step = _Step.otp;
      });
    }
  });

  Future<void> _verify() => _run(() async {
    try {
      await _repo.verifyOtp(_phone, _otpField.text.trim());
    } on AuthException {
      return _fail("That code isn't right. Check it and try again.");
    } catch (_) {
      return _fail(
        'Something went wrong. Check your connection and try again.',
      );
    }
    await _afterSignIn();
  });

  Future<void> _saveName() => _run(() async {
    final name = _nameField.text.trim();
    if (name.isEmpty) return _fail('Please enter your name.');
    try {
      await _repo.setName(name);
    } catch (_) {
      return _fail("We couldn't save your name. Try again.");
    }
    if (mounted) Navigator.of(context).pop(true);
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        32 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Calm.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Calm.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              switch (_step) {
                _Step.choose => _choose(),
                _Step.phone => PhoneStep(
                  controller: _phoneField,
                  onSend: _sendCode,
                  onBack: () => setState(() {
                    _step = _Step.choose;
                    _error = null;
                  }),
                  busy: _busy,
                  error: _error,
                ),
                _Step.otp => OtpStep(
                  phone: _phone,
                  controller: _otpField,
                  onVerify: _verify,
                  onChangeNumber: () => setState(() {
                    _step = _Step.phone;
                    _error = null;
                    _otpField.clear();
                  }),
                  busy: _busy,
                  error: _error,
                ),
                _Step.name => NameStep(
                  controller: _nameField,
                  onContinue: _saveName,
                  busy: _busy,
                  error: _error,
                ),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _choose() {
    final (title, note) =
        _copy[widget.reason] ?? ('Sign in', 'Browsing stays open.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: Calm.serif,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(note, style: const TextStyle(color: Calm.mut)),
        const SizedBox(height: 16),
        JomButton(
          label: 'Continue with Google',
          onPressed: _google,
          busy: _busy,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Calm.bad)),
          ),
        const SizedBox(height: 10),
        JomButton(
          label: 'Continue with phone number',
          primary: false,
          onPressed: () => setState(() {
            _step = _Step.phone;
            _error = null;
          }),
        ),
      ],
    );
  }
}
