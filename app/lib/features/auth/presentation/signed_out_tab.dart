import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../data/auth_repository.dart';
import 'sign_in_sheet.dart';

/// What Saved, Bookings, Chat and Profile show to someone who is not signed in. Browsing stays open; these
/// four tabs belong to an account.
class SignedOutTab extends ConsumerStatefulWidget {
  const SignedOutTab({super.key, required this.heading});

  final String heading;

  @override
  ConsumerState<SignedOutTab> createState() => _SignedOutTabState();
}

class _SignedOutTabState extends ConsumerState<SignedOutTab> {
  String? _error;
  bool _busy = false;

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on GoogleCancelled {
      // closed the Google window: nothing to say
    } on GoogleNotConfigured {
      _error = "Google sign-in isn't set up on this device yet. Use your phone number instead.";
    } catch (_) {
      _error =
          'Google sign-in went wrong. Try again, or use your phone number.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Calm.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40, color: Calm.mut),
                const SizedBox(height: 16),
                Text(
                  widget.heading,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: Calm.serif,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Browsing stays open. An account is only for joining, saving and chatting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Calm.mut),
                ),
                const SizedBox(height: 24),
                JomButton(
                  label: 'Continue with Google',
                  onPressed: _google,
                  busy: _busy,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Calm.bad),
                    ),
                  ),
                const SizedBox(height: 10),
                JomButton(
                  label: 'Continue with phone number',
                  primary: false,
                  onPressed: () =>
                      showSignInSheet(context, startWithPhone: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
