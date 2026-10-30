import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/clock.dart';
import '../../../core/theme/calm.dart';
import '../data/host_repository.dart';
import '../domain/scan_controller.dart';

/// The camera. Tests swap it for a stand-in; [onUnavailable] is called when the camera cannot start (permission denied).
typedef ScannerBuilder = Widget Function(
  BuildContext context, {
  required ValueChanged<String> onCode,
  required VoidCallback onUnavailable,
});

final scannerBuilderProvider = Provider<ScannerBuilder>(
  (ref) =>
      (context, {required onCode, required onUnavailable}) =>
          _Camera(onCode: onCode, onUnavailable: onUnavailable),
);

const _night = Color(0xFF0E1217);

/// Host mode: scan tickets (/host-mode/events/:id/scan). Only the camera area is dark, like the prototype.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  late final _controller = ScanController(
    (token) => ref.read(hostRepositoryProvider).checkIn(widget.id, token),
    now: ref.read(nowProvider),
  );
  ScanResult? _result;
  int _added = 0;
  bool _cameraOff = false;

  Future<void> _onCode(String raw) async {
    final r = await _controller.onCode(raw);
    // a debounced repeat hands back the same result: show it, count it once
    if (!mounted || identical(r, _result)) return;
    setState(() {
      if (r.kind == ScanKind.checkedIn) _added += r.people ?? 1;
      _result = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sold = ref.watch(hostEventProvider(widget.id)).value?.seatsSold ?? 0;
    final base = (ref.watch(hostGuestsProvider(widget.id)).value ?? [])
        .where((g) => g.checkedIn)
        .fold(0, (n, g) => n + g.people);
    final r = _result;
    return Scaffold(
      key: const Key('scan-screen'),
      backgroundColor: _night,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 5,
          20,
          30,
        ),
        children: [
          Row(
            children: [
              GestureDetector(
                key: const Key('nav-back'),
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.go('/host-mode/events/${widget.id}'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Scan tickets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                key: const Key('scan-counter'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Calm.okSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${base + _added} / $sold',
                  style: const TextStyle(
                    color: Calm.ok,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 300,
              child: _cameraOff
                  ? Container(
                      color: Colors.white.withValues(alpha: .08),
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Camera is off. Allow camera access in Settings, or use the manual list.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                          TextButton(
                            key: const Key('open-manual-list'),
                            onPressed: () => context.push(
                              '/host-mode/events/${widget.id}/checkin',
                            ),
                            child: const Text(
                              'Open the manual list',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ref.watch(scannerBuilderProvider)(
                          context,
                          onCode: _onCode,
                          onUnavailable: () =>
                              setState(() => _cameraOff = true),
                        ),
                        const Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: Text(
                              "Point the camera at the guest's ticket QR",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _ResultCard(r),
          if (kDebugMode) _PasteCode(_onCode),
          TextButton(
            key: const Key('manual-list-link'),
            onPressed: () =>
                context.push('/host-mode/events/${widget.id}/checkin'),
            child: const Text(
              'Enter code manually / see list',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.r);
  final ScanResult? r;

  @override
  Widget build(BuildContext context) {
    final r = this.r;
    final (bg, head, lines, subColor) = r == null
        ? (
            Colors.white.withValues(alpha: .08),
            'Waiting for a ticket',
            ['Valid tickets check the guest in automatically.'],
            Colors.white54,
          )
        : r.good
        ? (
            const Color(0xFF143A2A),
            '✓ ${r.name ?? ''}',
            [
              '${r.people ?? 1} ${(r.people ?? 1) == 1 ? 'person' : 'people'} · ${r.code ?? ''}',
              r.message,
            ],
            const Color(0xFFBFE9D0),
          )
        : (
            const Color(0xFF4A1F1B),
            r.message,
            [if (r.kind == ScanKind.notConfirmed && r.name != null) r.name!],
            const Color(0xFFF2B8B0),
          );
    return Container(
      key: const Key('scan-result'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            head,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final l in lines)
            Text(l, style: TextStyle(color: subColor, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Debug builds only: the simulator has no camera, so paste a ticket token here instead (the prototype's "Simulate a scan").
class _PasteCode extends StatelessWidget {
  const _PasteCode(this.onCode);
  final ValueChanged<String> onCode;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextField(
      key: const Key('debug-code'),
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        hintText: 'Debug: paste a ticket code',
        hintStyle: TextStyle(color: Colors.white38),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
      ),
      onSubmitted: onCode,
    ),
  );
}

class _Camera extends StatefulWidget {
  const _Camera({required this.onCode, required this.onUnavailable});
  final ValueChanged<String> onCode;
  final VoidCallback onUnavailable;

  @override
  State<_Camera> createState() => _CameraState();
}

class _CameraState extends State<_Camera> {
  final _c = MobileScannerController(formats: const [BarcodeFormat.qrCode]);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      MobileScanner(
        controller: _c,
        onDetect: (capture) {
          final raw = capture.barcodes.firstOrNull?.rawValue;
          if (raw != null) widget.onCode(raw);
        },
        errorBuilder: (context, _) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => widget.onUnavailable(),
          );
          return const SizedBox.shrink();
        },
      ),
      Align(
        alignment: Alignment.topRight,
        child: IconButton(
          key: const Key('torch'),
          onPressed: _c.toggleTorch,
          icon: const Icon(Icons.flashlight_on_outlined, color: Colors.white),
        ),
      ),
    ],
  );
}
