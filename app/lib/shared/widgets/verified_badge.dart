import 'package:flutter/material.dart';

import '../../core/theme/calm.dart';

/// The small accent tick beside a verified host's name. Show it only when the host is verified.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 14});
  final double size;

  @override
  Widget build(BuildContext context) => Icon(Icons.verified_outlined, key: const Key('verified-badge'), size: size, color: Calm.acc);
}
