import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/launcher.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';

// shortcut: placeholder address, confirm the real support inbox in Task 25 (release checklist).
const supportEmail = 'support@jom.app';

const _faq = [
  (
    'How do refunds work?',
    'Each host picks a cancel policy, shown on the event page. Cancel inside the free window and the money goes back to your original payment method in 3 to 7 working days.',
  ),
  (
    'How do I get into an event?',
    'Open the Tickets tab and show the QR code on your ticket to the host at the door.',
  ),
  (
    'Why can I not write a review?',
    'Only guests the host checked in can review, and only after the host has closed the event.',
  ),
  (
    'How do I delete my account?',
    'Profile, then Delete account. A host with guests booked must finish or cancel those events first.',
  ),
];

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    key: const Key('help-screen'),
    backgroundColor: Calm.bg,
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        const BookingNav(title: 'Help & support'),
        CardBox(
          onTap: () => ref.read(launchUrlProvider)(
            Uri(scheme: 'mailto', path: supportEmail),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Email us',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(supportEmail, style: const TextStyle(color: Calm.acc)),
              const Text(
                'We reply within two working days.',
                style: TextStyle(fontSize: 13, color: Calm.mut),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final (q, a) in _faq)
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  a,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Calm.mut,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
