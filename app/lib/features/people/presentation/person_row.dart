import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../domain/person.dart';

/// A letter circle (or the host's picture), the name and the @username. Tapping opens that person.
class PersonRow extends StatelessWidget {
  const PersonRow(this.p, {super.key});
  final Person p;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: Key('person-${p.userId}'),
    child: CardBox(
      gap: 8,
      onTap: () =>
          context.push(p.isHost ? '/host/${p.userId}' : '/people/${p.userId}'),
      child: Row(
        children: [
          PersonAvatar(p, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '@${p.username}',
                  style: const TextStyle(color: Calm.mut, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.p, {super.key, required this.size});
  final Person p;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Calm.accSoft,
      shape: BoxShape.circle,
      image: p.avatarUrl == null
          ? null
          : DecorationImage(
              image: NetworkImage(p.avatarUrl!),
              fit: BoxFit.cover,
            ),
    ),
    child: p.avatarUrl != null
        ? null
        : Text(
            p.name.characters.first.toUpperCase(),
            style: TextStyle(
              fontFamily: Calm.serif,
              fontSize: size * .38,
              color: Calm.acc,
            ),
          ),
  );
}
