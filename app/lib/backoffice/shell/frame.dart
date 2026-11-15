import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/calm.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/host/data/host_repository.dart';
import '../access/access.dart';

const _sidebarWidth = 236.0;
const _phoneBreakpoint = 760.0;

/// The back office frame: a left sidebar on tablet and desktop, a top bar with a menu on a phone.
/// Admins see Applications; a person who is both admin and host also gets the switch.
class Frame extends ConsumerWidget {
  const Frame({
    super.key,
    required this.shellKey,
    required this.title,
    required this.child,
  });
  final String shellKey;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminShell = shellKey == 'bo-admin-shell';
    final access = ref.watch(adminAccessProvider).value;
    final host = ref.watch(hostStatusProvider).value?.state.name == 'approved';
    final both = (access?.isAdmin ?? false) && host;
    final phone = MediaQuery.sizeOf(context).width <= _phoneBreakpoint;

    Widget nav() => _Nav(isAdminShell: isAdminShell, both: both);

    return Scaffold(
      key: Key(shellKey),
      backgroundColor: Calm.bg,
      appBar: phone
          ? AppBar(
              backgroundColor: Calm.surface,
              title: Text(
                title,
                style: const TextStyle(fontFamily: Calm.serif, fontSize: 18),
              ),
              leading: Builder(
                builder: (c) => IconButton(
                  key: const Key('bo-menu'),
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(c).openDrawer(),
                ),
              ),
            )
          : null,
      drawer: phone ? Drawer(child: SafeArea(child: nav())) : null,
      body: phone
          ? child
          : Row(
              children: [
                Container(
                  key: const Key('bo-sidebar'),
                  width: _sidebarWidth,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Calm.line)),
                  ),
                  child: Material(
                    color: Calm.surface,
                    child: SafeArea(child: nav()),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
    );
  }
}

class _Nav extends ConsumerWidget {
  const _Nav({required this.isAdminShell, required this.both});
  final bool isAdminShell;
  final bool both;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Text(
          'Jom back office',
          style: TextStyle(
            fontFamily: Calm.serif,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      if (isAdminShell)
        ListTile(
          key: const Key('bo-nav-applications'),
          selected: true,
          selectedTileColor: Calm.accSoft,
          selectedColor: Calm.acc,
          leading: const Icon(Icons.how_to_reg_outlined),
          title: const Text('Applications'),
          onTap: () {
            if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
          },
        ),
      const Spacer(),
      if (both)
        ListTile(
          key: const Key('bo-switch'),
          leading: const Icon(Icons.swap_horiz),
          title: Text(isAdminShell ? 'Switch to host' : 'Switch to admin'),
          onTap: () => ref
              .read(chosenShellProvider.notifier)
              .choose(isAdminShell ? Shell.host : Shell.admin),
        ),
      ListTile(
        key: const Key('bo-signout'),
        leading: const Icon(Icons.logout),
        title: const Text('Sign out'),
        onTap: () => ref.read(authRepositoryProvider).signOut(),
      ),
    ],
  );
}
