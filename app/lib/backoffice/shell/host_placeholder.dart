import 'package:flutter/material.dart';

import 'frame.dart';

/// The host side is the next step; approved hosts see this until then.
class HostPlaceholder extends StatelessWidget {
  const HostPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const Frame(
    shellKey: 'bo-host-shell',
    title: 'Host',
    child: Center(child: Text('Your host tools are coming soon.')),
  );
}
