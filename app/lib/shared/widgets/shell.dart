import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/grain.dart';
import '../../core/theme/tokens.dart';

/// Unread chat messages, shown on the Chat tab of both bars. Zero until the chat screens (Task 18) override it.
final chatBadgeCountProvider = Provider<int>((ref) => 0);

class _TabSpec {
  const _TabSpec(this.label, this.icon, {this.badge = false});
  final String label;
  final IconData icon;
  final bool badge; // does this tab carry the unread badge?
}

// shortcut: Material icons stand in for the prototype's custom SVG icons; swap in the exact drawings with
// flutter_svg if the difference matters.
const _attendee = [
  _TabSpec('Explore', Icons.explore_outlined),
  _TabSpec('Saved', Icons.favorite_border),
  _TabSpec('Bookings', Icons.confirmation_number_outlined),
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

/// The floating pill at the bottom of a tab screen.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.tabs, required this.currentIndex, required this.onTap, required this.badge});

  final List<_TabSpec> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    return DecoratedBox(
      key: const Key('tab-bar'),
      decoration: BoxDecoration(
        color: k.sheet,
        borderRadius: BorderRadius.circular(31),
        border: Border.all(color: k.line),
        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 34, offset: Offset(0, 14))],
      ),
      child: SizedBox(
        height: 62,
        child: Padding(
          padding: const EdgeInsets.all(6),
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
    final k = context.jom;
    final ink = selected ? k.accentInk : k.sheetInk;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        key: Key('tab-${selected ? 'on' : 'off'}:${spec.label}'),
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(color: selected ? k.accent : Colors.transparent, borderRadius: BorderRadius.circular(25)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: selected ? 1 : .55,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(spec.icon, size: 22, color: ink),
                const SizedBox(height: 2),
                Text(spec.label, style: TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (badge > 0)
              Positioned(
                top: 5,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(offset: const Offset(14, 0), child: _Badge(count: badge)),
                ),
              ),
          ],
        ),
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
      alignment: Alignment.center,
      decoration: BoxDecoration(color: const Color(0xFFFF4D6D), borderRadius: BorderRadius.circular(8)),
      child: Text(count > 9 ? '9+' : '$count',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1)),
    );
  }
}

/// Explore, Saved, Bookings, Chat, Profile.
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

/// The frame around the tab screens: the screen, film grain over it, and the floating tab bar.
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
      body: GrainBackground(
        child: Stack(children: [
          Positioned.fill(child: navigationShell),
          Positioned(
            left: 24,
            right: 24,
            bottom: math.max(16, MediaQuery.paddingOf(context).bottom),
            child: bar,
          ),
        ]),
      ),
    );
  }
}
