import 'dart:math';
import 'dart:ui';

// Ported from the prototype's layoutAlt('map') (docs/superpowers/kl-local-session-hifi.html): a seeded random
// start per event id, push pins apart to [minGap], scale the group to fill [area], push apart again, centre.
// Positions are relative to the centre of the pin area. Ids are sorted first, so the result never depends on
// the order the feed returned them in.

int _hash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c).toSigned(32);
  }
  return h.abs();
}

// mulberry32, bit for bit the prototype's rng. shortcut: relies on 64-bit ints (phones, not web).
double Function() _rng(int seed) {
  var a = seed.toSigned(32);
  int imul(int x, int y) => ((x * y) & 0xFFFFFFFF).toSigned(32);
  return () {
    a = (a + 0x6D2B79F5).toSigned(32);
    var t = imul(a ^ (a.toUnsigned(32) >> 15), 1 | a);
    t = ((t + imul(t ^ (t.toUnsigned(32) >> 7), 61 | t)) ^ t).toSigned(32);
    return ((t ^ (t.toUnsigned(32) >> 14)).toUnsigned(32)) / 4294967296;
  };
}

void _relax(List<double> xs, List<double> ys, double gap, int rounds) {
  for (var it = 0; it < rounds; it++) {
    for (var i = 0; i < xs.length; i++) {
      for (var j = i + 1; j < xs.length; j++) {
        final dx = xs[j] - xs[i], dy = ys[j] - ys[i];
        final d = sqrt(dx * dx + dy * dy);
        if (d >= gap) continue;
        final k = (gap - (d == 0 ? 1 : d)) / 2 / (d == 0 ? 1 : d);
        final ux = d == 0 ? 1.0 : dx, uy = d == 0 ? 0.0 : dy;
        xs[i] -= ux * k;
        ys[i] -= uy * k;
        xs[j] += ux * k;
        ys[j] += uy * k;
      }
    }
    for (var i = 0; i < xs.length; i++) {
      xs[i] = xs[i].clamp(-148.0, 148.0);
      ys[i] = ys[i].clamp(-158.0, 62.0);
    }
  }
}

Offset _centre(List<double> xs, List<double> ys) => Offset((xs.reduce(min) + xs.reduce(max)) / 2, (ys.reduce(min) + ys.reduce(max)) / 2);

List<Offset> layoutPins(List<String> ids, {Size area = const Size(215, 190), double minGap = 72}) {
  if (ids.isEmpty) return const [];
  final order = [...ids]..sort();
  final xs = <double>[], ys = <double>[];
  for (final id in order) {
    final r = _rng(_hash(id) + 7);
    xs.add((r() * 2 - 1) * 135);
    ys.add(-135 + r() * 170);
  }
  _relax(xs, ys, 74, 160);

  final c = _centre(xs, ys);
  final w = max(xs.reduce(max) - xs.reduce(min), 1.0), h = max(ys.reduce(max) - ys.reduce(min), 1.0);
  final sx = min(1.9, area.width / w), sy = min(1.9, area.height / h);
  for (var i = 0; i < xs.length; i++) {
    xs[i] = (xs[i] - c.dx) * sx;
    ys[i] = (ys[i] - c.dy) * sy;
  }
  _relax(xs, ys, minGap, 80);

  final m = _centre(xs, ys);
  final byId = {for (var i = 0; i < order.length; i++) order[i]: Offset(xs[i] - m.dx, ys[i] - m.dy)};
  return [for (final id in ids) byId[id]!];
}
