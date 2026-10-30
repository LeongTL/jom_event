import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/location.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/jom_switch.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../event/domain/event_labels.dart';
import '../data/host_repository.dart';
import '../domain/event_form_state.dart';
import '../domain/host.dart';
import 'delete_sheet.dart';
import 'host_parts.dart';

const _categories = [
  ('make', 'Make'),
  ('move', 'Move'),
  ('meet', 'Meet'),
  ('other', 'Other'),
];
const _policies = [
  ('24h', '24 h before'),
  ('48h', '48 h before'),
  ('7d', '7 days before'),
  ('none', 'No refunds'),
];
const _kl = Duration(hours: 8);

/// New event (/host-mode/new), or edit a draft or published event (/host-mode/events/:id/edit). A published event
/// locks everything but title, description and spots.
class EventFormScreen extends ConsumerWidget {
  const EventFormScreen({super.key, this.id});
  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id == null) return const _EventForm(row: null);
    return ref
        .watch(hostEventProvider(id!))
        .when(
          loading: () =>
              Scaffold(backgroundColor: Calm.bg, body: hostLoading()),
          error: (_, _) => Scaffold(
            backgroundColor: Calm.bg,
            body: hostFailed('this event'),
          ),
          data: (row) => row == null
              ? const Scaffold(
                  key: Key('event-missing'),
                  backgroundColor: Calm.bg,
                  body: Center(
                    child: Text(
                      'This event is not available.',
                      style: TextStyle(color: Calm.mut),
                    ),
                  ),
                )
              : _EventForm(row: row),
        );
  }
}

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({required this.row});
  final HostEventRow? row;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  late EventForm _f = widget.row == null
      ? const EventForm()
      : EventForm.fromRow(widget.row!);
  late final _title = TextEditingController(text: _f.title);
  late final _desc = TextEditingController(text: _f.description);
  late final _venue = TextEditingController(text: _f.venue);
  late final _price = TextEditingController(
    text: _f.priceSen == 0
        ? ''
        : '${_f.priceSen / 100}'.replaceFirst(RegExp(r'\.0$'), ''),
  );
  late String? _savedId = widget.row?.id; // set once a draft exists, so a failed publish does not save a second draft
  bool _busy = false;
  String? _error;

  EditMode get _mode => widget.row?.status == 'published'
      ? EditMode.publishedEdit
      : EditMode.create;
  bool get _locked => _mode == EditMode.publishedEdit;
  int get _sold => widget.row?.seatsSold ?? 0;

  void _set(EventForm f) => setState(() => _f = f);

  void _toggleCategory(String v) {
    final on = _f.categories.contains(v);
    _set(
      _f.copyWith(
        categories: on
            ? [
                for (final c in _f.categories)
                  if (c != v) c,
              ]
            : [..._f.categories, v],
      ),
    );
  }

  Future<void> _pickWhen() async {
    final now = ref.read(nowProvider)();
    final nowKl = now.add(_kl);
    final date = await showDatePicker(
      context: context,
      initialDate: _f.startsAt?.add(_kl) ?? nowKl.add(const Duration(days: 1)),
      firstDate: nowKl,
      lastDate: nowKl.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 2) % 24, minute: start.minute),
    );
    if (end == null) return;
    // the pickers speak Kuala Lumpur time whatever the phone's zone is
    DateTime at(TimeOfDay t) => DateTime.utc(
      date.year,
      date.month,
      date.day,
      t.hour,
      t.minute,
    ).subtract(_kl);
    final s = at(start);
    var e = at(end);
    if (!e.isAfter(s)) e = e.add(const Duration(days: 1));
    _set(_f.copyWith(startsAt: s, endsAt: e));
  }

  // runs [action] with the busy flag and the server's refusal shown in words; [then] only when it worked
  Future<void> _run(Future<void> Function() action) async {
    final go = GoRouter.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(hostEventsProvider);
      ref.invalidate(hostEventProvider);
      ref.invalidate(hostDashboardProvider);
      go.go('/host-mode/events');
    } on HostError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.text;
      });
    }
  }

  Future<String> _save() async => _savedId = await ref
      .read(hostRepositoryProvider)
      .saveDraft(_f, id: _savedId);

  Future<void> _delete() async {
    final go = GoRouter.of(context);
    if (await showDeleteSheet(context, widget.row!) != true) return;
    ref.invalidate(hostEventsProvider);
    ref.invalidate(hostDashboardProvider);
    go.go('/host-mode/events');
  }

  Widget _stepper() {
    Widget btn(String k, String label, int by) => GestureDetector(
      key: Key(k),
      behavior: HitTestBehavior.opaque,
      onTap: () => _set(
        _f.copyWith(
          capacity: clampSpots(_f.capacity + by, mode: _mode, sold: _sold),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(label, style: const TextStyle(fontSize: 22)),
      ),
    );
    return FieldBox(
      label: 'Spots',
      child: Row(
        children: [
          btn('spots-minus', '−', -1),
          Expanded(
            child: Center(
              child: Text(
                '${_f.capacity}',
                key: const Key('spots-value'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          btn('spots-plus', '+', 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider)();
    final row = widget.row;
    final lock = _locked;
    final canPublish = _f.problem(now) == null;
    final canDelete =
        row != null &&
        (row.status == 'draft' ||
            (row.startsAt != null && row.startsAt!.isAfter(now)));
    final me = ref.watch(hostMeProvider).value;
    final when = _f.startsAt == null
        ? null
        : '${dayLabel(_f.startsAt!, now)} · ${timeLabel(_f.startsAt!)} – ${timeLabel(_f.endsAt!)}';

    return Scaffold(
      backgroundColor: Calm.bg,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
            children: [
              BookingNav(title: row == null ? 'New event' : 'Edit event'),
              if (lock)
                SoftNote(
                  _sold > 0
                      ? '$_sold ${_sold == 1 ? 'guest has' : 'guests have'} joined. You can change the title, description and spots. Date, place, price and refund window are locked so nobody is surprised after paying.'
                      : 'Once published you can change the title, description and spots. The rest is locked.',
                ),
              HostField(
                label: 'Title',
                fieldKey: const Key('form-title'),
                controller: _title,
                hint: 'Give your event a name',
                onChanged: (v) => _set(_f.copyWith(title: v)),
              ),
              HostField(
                label: 'Description',
                fieldKey: const Key('form-description'),
                controller: _desc,
                lines: 3,
                hint: 'What will guests do?',
                onChanged: (v) => _set(_f.copyWith(description: v)),
              ),
              FieldBox(
                label: 'Category',
                lock: lock ? 'categories' : null,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (v, label) in _categories)
                      KeyedSubtree(
                        key: Key('cat-$v'),
                        child: PickChip(
                          label,
                          on: _f.categories.contains(v),
                          onTap: lock ? null : () => _toggleCategory(v),
                        ),
                      ),
                  ],
                ),
              ),
              FieldBox(
                key: const Key('field-when'),
                label: 'When',
                lock: lock ? 'when' : null,
                onTap: _pickWhen,
                child: Text(
                  when ?? 'Pick a date and time',
                  style: TextStyle(
                    fontSize: 15.5,
                    color: when == null ? Calm.faint : Calm.ink,
                  ),
                ),
              ),
              HostField(
                label: 'Where',
                fieldKey: const Key('form-venue'),
                controller: _venue,
                hint: 'Venue and address',
                lock: lock ? 'where' : null,
                onChanged: (v) => _set(_f.copyWith(venue: v)),
              ),
              FieldBox(
                label: 'Area',
                lock: lock ? 'area' : null,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in kAreas.keys)
                      KeyedSubtree(
                        key: Key('form-area-$a'),
                        child: PickChip(
                          a,
                          on: _f.area == a,
                          onTap: lock ? null : () => _set(_f.copyWith(area: a)),
                        ),
                      ),
                  ],
                ),
              ),
              CardCols(
                label: 'Accept bookings',
                note: 'Guests pay online to join',
                lock: lock ? 'accept' : null,
                trailing: KeyedSubtree(
                  key: const Key('form-accept'),
                  child: JomSwitch(
                    value: _f.acceptBookings,
                    onChanged: lock
                        ? null
                        : (v) => _set(_f.copyWith(acceptBookings: v)),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: HostField(
                      label: 'Price',
                      fieldKey: const Key('form-price'),
                      controller: _price,
                      prefix: 'RM ',
                      hint: '0',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      lock: lock ? 'price' : null,
                      onChanged: (v) => _set(
                        _f.copyWith(
                          priceSen: ((double.tryParse(v) ?? 0) * 100).round(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _stepper()),
                ],
              ),
              if (lock && _sold > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 10),
                  child: Text(
                    "$_sold already joined, so spots can't go below $_sold.",
                    style: const TextStyle(color: Calm.mut, fontSize: 13),
                  ),
                ),
              FieldBox(
                label: 'Guests can cancel for a refund up to',
                lock: lock ? 'policy' : null,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (v, label) in _policies)
                      KeyedSubtree(
                        key: Key('policy-$v'),
                        child: PickChip(
                          label,
                          on: _f.cancelPolicy == v,
                          onTap: lock
                              ? null
                              : () => _set(_f.copyWith(cancelPolicy: v)),
                        ),
                      ),
                  ],
                ),
              ),
              if (me != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 2, 2, 14),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(color: Calm.mut),
                      children: [
                        TextSpan(text: 'Payouts to ${me.accountLabel} · '),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () =>
                                context.push('/host-mode/payout-account'),
                            child: const Text(
                              'change',
                              style: TextStyle(
                                color: Calm.acc,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SoftNote(
                'After the event, mark it completed yourself, or it completes automatically 24 hours after it ends. Completing unlocks reviews and your payout.',
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Calm.bad,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (canDelete)
                KeyedSubtree(
                  key: const Key('delete-event'),
                  child: JomButton(
                    label: 'Delete this event',
                    primary: false,
                    onPressed: _delete,
                  ),
                ),
            ],
          ),
          CtaBar(
            children: lock
                ? [
                    Expanded(
                      child: KeyedSubtree(
                        key: const Key('cancel-edit'),
                        child: JomButton(
                          label: 'Cancel',
                          primary: false,
                          onPressed: () => context.go('/host-mode/events'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KeyedSubtree(
                        key: const Key('save-changes'),
                        child: JomButton(
                          label: 'Save changes',
                          busy: _busy,
                          onPressed: _f.title.trim().isEmpty
                              ? null
                              : () => _run(
                                  () => ref
                                      .read(hostRepositoryProvider)
                                      .update(
                                        row!.id,
                                        title: _f.title.trim(),
                                        description: _f.description.trim(),
                                        capacity: _f.capacity,
                                      ),
                                ),
                        ),
                      ),
                    ),
                  ]
                : [
                    Expanded(
                      child: KeyedSubtree(
                        key: const Key('save-draft'),
                        child: JomButton(
                          label: 'Save draft',
                          primary: false,
                          busy: _busy,
                          onPressed: _f.title.trim().isEmpty
                              ? null
                              : () => _run(_save),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KeyedSubtree(
                        key: const Key('publish'),
                        child: JomButton(
                          label: 'Publish',
                          busy: _busy,
                          onPressed: canPublish
                              ? () => _run(
                                  () async => ref
                                      .read(hostRepositoryProvider)
                                      .publish(await _save()),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

/// A card with a title and note on the left and a control on the right (prototype `.card.row`).
class CardCols extends StatelessWidget {
  const CardCols({
    super.key,
    required this.label,
    required this.note,
    required this.trailing,
    this.lock,
  });
  final String label, note;
  final Widget trailing;
  final String? lock;

  @override
  Widget build(BuildContext context) => CardBox(
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (lock != null) LockIcon(lock!),
                ],
              ),
              Text(note, style: const TextStyle(color: Calm.mut, fontSize: 13)),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}
