import 'package:flutter/material.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../domain/phone_number.dart';

/// Step: type the 6 digit code that was texted.
class OtpStep extends StatelessWidget {
  const OtpStep({
    super.key,
    required this.phone,
    required this.controller,
    required this.onVerify,
    required this.onChangeNumber,
    required this.busy,
    this.error,
  });

  final String phone; // +60...
  final TextEditingController controller;
  final VoidCallback onVerify;
  final VoidCallback onChangeNumber;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Enter the code',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'We sent a 6 digit code to',
          style: TextStyle(color: k.sheetInk.withValues(alpha: .7)),
        ),
        Text(
          prettyMyPhone(phone),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('otp-field'),
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          maxLength: 6,
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.w700,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '------',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => onVerify(),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error!,
              style: const TextStyle(color: Color(0xFFFF5A67)),
            ),
          ),
        const SizedBox(height: 16),
        JomButton(label: 'Verify', onPressed: onVerify, busy: busy),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: onChangeNumber,
            child: const Text('Use a different number'),
          ),
        ),
      ],
    );
  }
}
