import 'package:flutter/material.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';

/// Step: type your phone number.
class PhoneStep extends StatelessWidget {
  const PhoneStep({super.key, required this.controller, required this.onSend, required this.onBack, required this.busy, this.error});

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onBack;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text('Your phone number', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text("We'll text you a 6 digit code.", style: TextStyle(color: k.sheetInk.withValues(alpha: .7))),
      const SizedBox(height: 16),
      TextField(
        key: const Key('phone-field'),
        controller: controller,
        keyboardType: TextInputType.phone,
        autofocus: true,
        decoration: const InputDecoration(prefixText: '+60  ', hintText: '12 345 6789', border: OutlineInputBorder()),
        onSubmitted: (_) => onSend(),
      ),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Color(0xFFFF5A67)))),
      const SizedBox(height: 16),
      JomButton(label: 'Send code', onPressed: onSend, busy: busy),
      const SizedBox(height: 6),
      Center(child: TextButton(onPressed: onBack, child: const Text('Back'))),
    ]);
  }
}
