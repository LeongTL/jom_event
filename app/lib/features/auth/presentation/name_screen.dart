import 'package:flutter/material.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';

/// Step: a new account says what to call them (hosts see this name).
class NameStep extends StatelessWidget {
  const NameStep({super.key, required this.controller, required this.onContinue, required this.busy, this.error});

  final TextEditingController controller;
  final VoidCallback onContinue;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text('What should we call you?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('This is the name hosts see when you join.', style: TextStyle(color: k.sheetInk.withValues(alpha: .7))),
      const SizedBox(height: 16),
      TextField(
        key: const Key('name-field'),
        controller: controller,
        textCapitalization: TextCapitalization.words,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Your name', border: OutlineInputBorder()),
        onSubmitted: (_) => onContinue(),
      ),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Color(0xFFFF5A67)))),
      const SizedBox(height: 16),
      JomButton(label: 'Continue', onPressed: onContinue, busy: busy),
    ]);
  }
}
