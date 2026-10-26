
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/calm.dart';
import '../../features/chat/data/chat_repository.dart';

/// Threads with something unread, shown on the Chat tab of both bars.
final chatBadgeCountProvider = Provider<int>((ref) => ref.watch(chatUnreadProvider).value ?? 0);

class _TabSpec {
  const _TabSpec(this.label, this.icon, {this.badge = false});
  final String label;
  final IconData icon;
  final bool badge; // does this tab carry the unread badge?
}

// shortcut: Material icons stand in for the prototype's line icons; swap in the exact drawings with flutter_svg if the
// difference matters.
const _attendee = [
  _TabSpec('Explore', Icons.explore_outlined),
  _TabSpec('Saved', Icons.favorite_border),
  _TabSpec('Tickets', Icons.confirmation_number_outlined),
  _TabSpec('Chat', Icons.chat_bubble_outline, badge: true),
  _TabSpec('Profile', Icons.person_outline),
];

const _host = [
  _TabSpec('Home', Icons.grid_view_outlined),
  _TabSpec('Events', Icons.calendar_today_outlined),
  _TabSpec('Payouts', Icons.payments_outlined),
  _TabSpec('Chat', Icons.chat_bubble_outline, badge: true),
  _TabSpec('Profile', Icons.person_outline),
];

/// The white bar at the bottom of a tab screen: a hairline on top, the active tab in the accent colour.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.tabs, required this.currentIndex, required this.onTap, required this.badge});

  final List<_TabSpec> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('tab-bar'),
      decoration: const BoxDecoration(color: Calm.surface, border: Border(top: BorderSide(color: Calm.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _TabItem(
                    spec: tabs[i],
                    selected: i == currentIndex,
                    badge: tabs[i].badge ? badge : 0,
                    onTap: () => onTap(i),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.spec, required this.selected, required this.badge, required this.onTap});

  final _TabSpec spec;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Calm.acc : Calm.faint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        key: Key('tab-${selected ? 'on' : 'off'}:${spec.label}'),
        alignment: Alignment.topCenter,
        children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 4),
            Icon(spec.icon, size: 22, color: ink),
            const SizedBox(height: 3),
            Text(spec.label, style: TextStyle(color: ink, fontSize: 10.5, fontWeight: FontWeight.w500)),
          ]),
          if (badge > 0) Positioned(top: 0, left: 0, right: 0, child: Align(alignment: Alignment.topCenter, child: Transform.translate(offset: const Offset(14, 0), child: _Badge(count: badge)))),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('tab-badge'),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      // no `alignment` here: a Container with one fills all the width it is given, which made a bar across the tab
      decoration: BoxDecoration(color: Calm.badge, borderRadius: BorderRadius.circular(8), border: Border.all(color: Calm.surface, width: 2)),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(count > 9 ? '9+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, height: 1)),
      ),
    );
  }
}

/// Explore, Saved, Tickets, Chat, Profile.
class AttendeeTabs extends StatelessWidget {
  const AttendeeTabs({super.key, required this.currentIndex, required this.onTap, this.chatBadge = 0});
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int chatBadge;

  @override
  Widget build(BuildContext context) =>
      _TabBar(tabs: _attendee, currentIndex: currentIndex, onTap: onTap, badge: chatBadge);
}

/// Home, Events, Payouts, Chat, Profile (host mode).
class HostTabs extends StatelessWidget {
  const HostTabs({super.key, required this.currentIndex, required this.onTap, this.chatBadge = 0});
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int chatBadge;

  @override
  Widget build(BuildContext context) => _TabBar(tabs: _host, currentIndex: currentIndex, onTap: onTap, badge: chatBadge);
}

/// The frame around the tab screens: the screen above, the tab bar below.
class JomShell extends ConsumerWidget {
  const JomShell({super.key, required this.navigationShell, required this.host});

  final StatefulNavigationShell navigationShell;
  final bool host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = ref.watch(chatBadgeCountProvider);
    void select(int i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);
    final bar = host
        ? HostTabs(currentIndex: navigationShell.currentIndex, onTap: select, chatBadge: badge)
        : AttendeeTabs(currentIndex: navigationShell.currentIndex, onTap: select, chatBadge: badge);
    return Scaffold(
      body: Column(children: [
        Expanded(child: navigationShell),
        bar,
      ]),
    );
  }
}
