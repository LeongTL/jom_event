import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';

/// A labelled text field in the Calm form style. [lock] draws the lock icon and makes it read-only (prototype .fld.lock).
class HostField extends StatelessWidget {
  const HostField({
    super.key,
    required this.label,
    this.fieldKey,
    this.controller,
    this.hint,
    this.lines = 1,
    this.lock,
    this.keyboard,
    this.onChanged,
    this.prefix,
  });
  final String label;
  final Key? fieldKey;
  final TextEditingController? controller;
  final String? hint, prefix;
  final int lines;
  final String? lock; // the lock icon's key suffix; null = editable
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => FieldBox(
    label: label,
    lock: lock,
    child: TextField(
      key: fieldKey,
      controller: controller,
      readOnly: lock != null,
      minLines: lines,
      maxLines: lines,
      keyboardType: keyboard,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15.5),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        prefixText: prefix,
        hintStyle: const TextStyle(color: Calm.faint),
      ),
    ),
  );
}

/// The framed box under a small label; [lock] greys it and adds the lock icon.
class FieldBox extends StatelessWidget {
  const FieldBox({
    super.key,
    required this.label,
    required this.child,
    this.lock,
    this.onTap,
  });
  final String label;
  final Widget child;
  final String? lock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Calm.mut,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (lock != null) LockIcon(lock!),
            ],
          ),
        ),
        GestureDetector(
          onTap: lock == null ? onTap : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: lock == null ? Calm.surface : Calm.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Calm.line),
            ),
            child: child,
          ),
        ),
      ],
    ),
  );
}

class LockIcon extends StatelessWidget {
  const LockIcon(this.suffix, {super.key});
  final String suffix;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 5),
    child: Icon(
      Icons.lock_outline,
      key: Key('lock-$suffix'),
      size: 13,
      color: Calm.faint,
    ),
  );
}

/// A rounded selectable chip (prototype .chip). A null [onTap] makes it fixed.
class PickChip extends StatelessWidget {
  const PickChip(this.label, {super.key, required this.on, this.onTap});
  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: on ? Calm.accSoft : Calm.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: on ? Calm.acc : Calm.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: on ? Calm.acc : Calm.ink,
        ),
      ),
    ),
  );
}

/// A quiet note (prototype .soft).
class SoftNote extends StatelessWidget {
  const SoftNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Calm.soft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: Calm.mut, height: 1.4),
    ),
  );
}

/// The "New event" button that floats above the tab bar. Put it last in a Stack.
class NewEventButton extends StatelessWidget {
  const NewEventButton({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
    left: 20,
    right: 20,
    bottom: 12,
    child: KeyedSubtree(
      key: const Key('new-event-button'),
      child: JomButton(
        label: '+  New event',
        onPressed: () => context.push('/host-mode/new'),
      ),
    ),
  );
}

/// A tiny status line for a loading or failed host screen.
Widget hostLoading() =>
    const Center(child: CircularProgressIndicator(color: Calm.acc));
Widget hostFailed(String what) => Center(
  child: Text(
    'Could not load $what. Check your connection.',
    style: const TextStyle(color: Calm.mut),
  ),
);
