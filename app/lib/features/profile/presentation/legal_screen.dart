import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';

/// Terms of use, then the privacy policy, both from the markdown files in assets/legal. Only "# " headings,
/// "## " sub-headings and plain paragraphs are understood.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  final _docs = Future.wait([
    rootBundle.loadString('assets/legal/terms.md'),
    rootBundle.loadString('assets/legal/privacy.md'),
  ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('legal-screen'),
    backgroundColor: Calm.bg,
    body: FutureBuilder(
      future: _docs,
      builder: (context, snap) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          const BookingNav(title: 'Terms & privacy'),
          for (final doc in snap.data ?? const <String>[])
            for (final line
                in doc.split('\n').where((l) => l.trim().isNotEmpty))
              if (line.startsWith('# '))
                Padding(
                  padding: const EdgeInsets.only(top: 22, bottom: 8),
                  child: Text(
                    line.substring(2),
                    style: const TextStyle(
                      fontFamily: Calm.serif,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (line.startsWith('## '))
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    line.substring(3),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Calm.mut,
                    ),
                  ),
                ),
        ],
      ),
    ),
  );
}
