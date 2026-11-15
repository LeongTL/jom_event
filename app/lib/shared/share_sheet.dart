import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/calm.dart';

/// The address share links are built on (SHARE_BASE_URL). Empty until the domain exists; main() sets it from the
/// build's settings, tests set it themselves.
final shareBaseUrlProvider = Provider<String>((ref) => '');

/// Opens the system share sheet with [message]. Tests replace it to see what would be sent.
final shareProvider = Provider<Future<void> Function(String message)>(
  (ref) =>
      (message) => SharePlus.instance.share(ShareParams(text: message)),
);

/// The round share button on a page's top bar.
class ShareButton extends ConsumerWidget {
  const ShareButton({super.key, required this.message});

  /// The whole message: the text, a line break and the link (see `shareMessage`).
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
    onTap: () => ref.read(shareProvider)(message),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.ios_share, size: 20, color: Calm.ink),
    ),
  );
}
