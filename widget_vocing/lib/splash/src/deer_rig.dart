// Lingua Splash — rig del venado.
//
// El venado es un esqueleto 3D (patas, cuello, cabeza, astas) cuyas piezas se
// proyectan con la cámara de la escena y se dibujan como primitivas 2D
// (elipses, cápsulas cónicas y envolventes convexas). La silueta resultante
// se puede "erosionar" encogiendo cada primitiva, lo que da el borde interior
// del rim light sin operaciones booleanas de paths.

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'scene.dart';

// ───────────────────────── marcha ─────────────────────────
// Ángulos por segmento [superior, medio, caña, cuartilla] medidos desde la
// vertical; + = hacia delante. p = 0 aterrizan las manos, 0–0.3 apoyo, 0.3–1 vuelo.

class _Key {
  const _Key(this.p, this.a);
  final double p;
  final List<double> a;
}

const List<_Key> _frontKeys = [
  _Key(0.0, [0.3, 0.25, 0.15, 0.35]),
  _Key(0.15, [0.0, -0.05, -0.12, 0.2]),
  _Key(0.35, [-0.3, 1.1, -0.9, -0.6]),
  _Key(0.6, [-0.15, 1.45, -1.3, -0.8]),
  _Key(0.82, [0.35, 0.9, 0.6, 0.7]),
  _Key(1.0, [0.3, 0.25, 0.15, 0.35]),
];
const List<_Key> _hindKeys = [
  _Key(0.0, [-0.1, -0.9, -0.4, -0.3]),
  _Key(0.15, [0.95, -0.35, 0.55, 0.5]),
  _Key(0.3, [0.0, -1.1, -0.9, -0.8]),
  _Key(0.55, [-0.35, -1.45, -1.35, -1.2]),
  _Key(0.85, [0.4, -1.0, 0.0, 0.1]),
  _Key(1.0, [-0.1, -0.9, -0.4, -0.3]),
];
const List<double> _frontStand = [-0.087, 0.08, 0.045, 0.24];
const List<double> _hindStand = [0.56, -0.72, 0.16, 0.24];
const List<double> _frontLen = [0.23, 0.25, 0.22, 0.08];
const List<double> _hindLen = [0.283, 0.333, 0.253, 0.082];
const List<double> _frontRad = [0.095, 0.062, 0.038, 0.03, 0.034];
const List<double> _hindRad = [0.14, 0.08, 0.042, 0.031, 0.035];

List<double> _sampleKeys(List<_Key> keys, double p) {
  final q = p % 1.0;
  for (var i = 0; i < keys.length - 1; i++) {
    final k0 = keys[i], k1 = keys[i + 1];
    if (q <= k1.p) {
      final u = easeCos((q - k0.p) / (k1.p - k0.p));
      return List<double>.generate(4, (j) => lerpD(k0.a[j], k1.a[j], u));
    }
  }
  return List<double>.of(keys.first.a);
}

List<double> _mix(List<double> a, List<double> b, double w) =>
    List<double>.generate(4, (j) => lerpD(a[j], b[j], w));

// ───────────────────────── anatomía ─────────────────────────

// [x, y, a(largo), b(alto), c(ancho)] en coordenadas locales del venado.
const List<List<double>> _torso = [
  [-0.52, 0.88, 0.19, 0.18, 0.12], // 0 grupa
  [-0.36, 0.82, 0.22, 0.22, 0.15], // 1 anca
  [-0.12, 0.85, 0.2, 0.16, 0.16], // 2 ijar (más alto: cintura)
  [0.08, 0.8, 0.26, 0.2, 0.17], // 3 vientre
  [0.32, 0.83, 0.22, 0.23, 0.17], // 4 pecho
  [0.38, 0.95, 0.16, 0.13, 0.13], // 5 cruz
  [0.47, 0.74, 0.12, 0.14, 0.12], // 6 pecho bajo
  [-0.69, 0.92, 0.035, 0.075, 0.04], // 7 cola
];

// Viga del asta en el marco de la cabeza: [hocico, arriba, lateral, radio].
const List<List<double>> _beam = [
  [-0.02, 0.075, 0.04, 0.03],
  [-0.09, 0.2, 0.12, 0.026],
  [-0.11, 0.36, 0.19, 0.022],
  [-0.06, 0.52, 0.23, 0.018],
  [0.04, 0.64, 0.22, 0.013],
  [0.12, 0.7, 0.19, 0.007],
];

// Puntas: [tramo, t sobre el tramo, Δhocico, Δarriba, Δlateral, radio base].
const List<List<double>> _tines = [
  [0.0, 0.3, 0.12, 0.09, 0.05, 0.02],
  [1.0, 0.6, 0.07, 0.17, -0.01, 0.019],
  [2.0, 0.6, 0.05, 0.17, -0.02, 0.016],
  [4.0, 0.0, -0.02, 0.15, -0.01, 0.012],
];

const double _pivot = 0.85; // pivote del cabeceo del cuerpo

// ───────────────────────── primitivas 2D ─────────────────────────

/// Todas las primitivas emiten polígonos en sentido horario en pantalla,
/// de modo que su unión con la regla nonzero es correcta.
abstract class DeerPrim {
  void emit(List<List<Offset>> out, double inset);
}

class _Ellipse implements DeerPrim {
  const _Ellipse(this.x, this.y, this.rx, this.ry);
  final double x, y, rx, ry;

  List<Offset> poly(double inset, int n) =>
      ellipsePoly(x, y, math.max(rx - inset, rx * 0.3), math.max(ry - inset, ry * 0.3), n);

  @override
  void emit(List<List<Offset>> out, double inset) => out.add(poly(inset, 26));
}

class _Capsule implements DeerPrim {
  const _Capsule(this.ax, this.ay, this.ra, this.bx, this.by, this.rb);
  final double ax, ay, ra, bx, by, rb;

  @override
  void emit(List<List<Offset>> out, double inset) => out.add(capsulePoly(
      ax, ay, math.max(ra - inset, ra * 0.3), bx, by, math.max(rb - inset, rb * 0.3)));
}

class _Hull implements DeerPrim {
  const _Hull(this.parts);
  final List<_Ellipse> parts;

  @override
  void emit(List<List<Offset>> out, double inset) {
    final pts = <Offset>[];
    for (final e in parts) {
      pts.addAll(e.poly(inset, 24));
    }
    out.add(convexHull(pts));
  }
}

List<Offset> ellipsePoly(double cx, double cy, double rx, double ry, int n) =>
    List<Offset>.generate(n, (i) {
      final a = tau * i / n;
      return Offset(cx + math.cos(a) * rx, cy + math.sin(a) * ry);
    });

/// Envolvente de dos círculos (cápsula cónica).
List<Offset> capsulePoly(double ax, double ay, double ra, double bx, double by, double rb) {
  final dx = bx - ax, dy = by - ay;
  final d = math.sqrt(dx * dx + dy * dy);
  if (d + math.min(ra, rb) <= math.max(ra, rb) + 1e-6) {
    return ra >= rb ? ellipsePoly(ax, ay, ra, ra, 18) : ellipsePoly(bx, by, rb, rb, 18);
  }
  final al = math.atan2(dy, dx);
  final be = math.acos(clampD((ra - rb) / d, -1, 1));
  const na = 12, nb = 8;
  final pts = <Offset>[];
  for (var i = 0; i <= na; i++) {
    final a = al + be + (tau - 2 * be) * i / na;
    pts.add(Offset(ax + math.cos(a) * ra, ay + math.sin(a) * ra));
  }
  for (var i = 0; i <= nb; i++) {
    final a = al - be + 2 * be * i / nb;
    pts.add(Offset(bx + math.cos(a) * rb, by + math.sin(a) * rb));
  }
  return pts;
}

/// Envolvente convexa (monotone chain); sentido horario en pantalla.
List<Offset> convexHull(List<Offset> input) {
  final pts = List<Offset>.of(input)
    ..sort((a, b) {
      final c = a.dx.compareTo(b.dx);
      return c != 0 ? c : a.dy.compareTo(b.dy);
    });
  double cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
  final lower = <Offset>[], upper = <Offset>[];
  for (final p in pts) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }
  for (final p in pts.reversed) {
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }
  lower.removeLast();
  upper.removeLast();
  return lower..addAll(upper);
}

// ───────────────────────── forma resultante ─────────────────────────

class GlowDot {
  const GlowDot(this.x, this.y, this.r, this.alpha);
  final double x, y, r, alpha;
}

class DeerShape {
  DeerShape({
    required this.prims,
    required this.antlerLines,
    required this.center,
    required this.eye,
    required this.rump,
    required this.scale,
  });

  final List<DeerPrim> prims;
  final List<List<Offset>> antlerLines;
  final Offset center;
  final GlowDot eye;
  final GlowDot rump;
  final double scale; // px por unidad a la altura del cuerpo

  /// Polígonos de la silueta encogida [inset] px.
  List<List<Offset>> polys(double inset) {
    final out = <List<Offset>>[];
    for (final p in prims) {
      p.emit(out, inset);
    }
    return out;
  }
}

class _Sphere {
  const _Sphere(this.x, this.y, this.r, this.z);
  final double x, y, r, z;
}

class _Leg {
  _Leg(this.joints, this.rad, this.lz);
  final List<Offset> joints; // (x, y) locales
  final List<double> rad;
  final double lz;
}

DeerShape buildDeer(DeerState ds, SplashCamera cam) {
  final prims = <DeerPrim>[];
  final antlerLines = <List<Offset>>[];
  final cyw = math.cos(ds.yaw), syw = math.sin(ds.yaw);
  final cb = math.cos(ds.bodyPitch), sb = math.sin(ds.bodyPitch);
  final f = cam.f;

  // Patas primero: el punto más bajo define el apoyo.
  final legs = <_Leg>[];
  var minHoof = double.infinity;
  for (final side in const [-1.0, 1.0]) {
    final off = side > 0 ? 0.0 : 0.03;
    final fr = _mix(_sampleKeys(_frontKeys, ds.p + off), _frontStand, ds.standW);
    final hd = _mix(_sampleKeys(_hindKeys, ds.p + off), _hindStand, ds.standW);
    final specs = [
      (0.42, 0.78, fr, _frontLen, _frontRad, 0.1 * side),
      (-0.45, 0.82, hd, _hindLen, _hindRad, 0.11 * side),
    ];
    for (final (rx0, ry0, ang, len, rad, lz) in specs) {
      final rx = rx0, ry = ry0 - _pivot;
      var jx = rx * cb - ry * sb;
      var jy = _pivot + rx * sb + ry * cb;
      final joints = <Offset>[Offset(jx, jy)];
      for (var i = 0; i < 4; i++) {
        final a = ang[i] + ds.bodyPitch * 0.5;
        jx += math.sin(a) * len[i];
        jy -= math.cos(a) * len[i];
        joints.add(Offset(jx, jy));
      }
      minHoof = math.min(minHoof, jy);
      legs.add(_Leg(joints, rad, lz));
    }
  }
  final lift = -minHoof * ds.plantW;

  Proj w3(double lx, double ly, double lz) => cam.project(
      ds.x + lx * syw - lz * cyw, ds.y + ly + lift, ds.z + lx * cyw + lz * syw);
  Offset pitched(double x, double y) {
    final py = y - _pivot;
    return Offset(x * cb - py * sb, _pivot + x * sb + py * cb);
  }

  _Sphere sphere(double lx, double ly, double lz, double r) {
    final s = w3(lx, ly, lz);
    return _Sphere(s.x, s.y, r * f / s.z, s.z);
  }

  void cap(_Sphere a, _Sphere b) => prims.add(_Capsule(a.x, a.y, a.r, b.x, b.y, b.r));

  // Patas: primero las del lado lejano.
  legs.sort((a, b) {
    final za = w3(a.joints[0].dx, a.joints[0].dy, a.lz).z;
    final zb = w3(b.joints[0].dx, b.joints[0].dy, b.lz).z;
    return zb.compareTo(za);
  });
  for (final l in legs) {
    var prev = sphere(l.joints[0].dx, l.joints[0].dy, l.lz, l.rad[0]);
    for (var i = 1; i < 5; i++) {
      final cur = sphere(l.joints[i].dx, l.joints[i].dy, l.lz, l.rad[i]);
      cap(prev, cur);
      prev = cur;
    }
  }

  // Torso: dos envolventes convexas (cuarto trasero y pecho) + cola.
  var cxSum = 0.0, cySum = 0.0;
  final ells = <_Ellipse>[];
  for (final e in _torso) {
    final q = pitched(e[0], e[1]);
    final s = w3(q.dx, q.dy, 0);
    final th = ds.yaw - math.atan((s.x - cam.cx) / f);
    final ax = e[2] * math.sin(th), cz = e[4] * math.cos(th);
    final rx = f / s.z * math.sqrt(ax * ax + cz * cz);
    final ry = f / s.z * e[3];
    cxSum += s.x;
    cySum += s.y;
    ells.add(_Ellipse(s.x, s.y, rx, ry));
  }
  prims
    ..add(_Hull([ells[0], ells[1], ells[2]]))
    ..add(_Hull([ells[3], ells[4], ells[5], ells[6]]))
    ..add(ells[7]);

  // Cuello.
  final nb = pitched(0.4, 0.97);
  final na = ds.neck + ds.bodyPitch;
  final ndx = math.cos(na), ndy = math.sin(na);
  _Sphere? prevN;
  for (var i = 0; i <= 5; i++) {
    final u = i / 5;
    final s = sphere(nb.dx + ndx * 0.46 * u, nb.dy + ndy * 0.46 * u, 0, lerpD(0.17, 0.09, u));
    if (prevN != null) cap(prevN, s);
    prevN = s;
  }
  final ntx = nb.dx + ndx * 0.46, nty = nb.dy + ndy * 0.46;

  // Cabeza (marco: h = hocico, n = arriba).
  final g = ds.head + ds.bodyPitch * 0.5;
  final hx = math.cos(g), hy = math.sin(g), nx = -math.sin(g), ny = math.cos(g);
  final skx = ntx + hx * 0.05 + nx * 0.015, sky = nty + hy * 0.05 + ny * 0.015;
  _Sphere hl(double a, double b, double w, double r) =>
      sphere(skx + hx * a + nx * b, sky + hy * a + ny * b, w, r);
  final skull = sphere(skx, sky, 0, 0.1);
  cap(prevN!, skull);
  cap(hl(0.03, 0, 0, 0.08), hl(0.25, -0.03, 0, 0.048));

  // Orejas.
  for (final side in const [-1.0, 1.0]) {
    final s0 = hl(-0.04, 0.06, 0.05 * side, 0.022);
    final s1 = hl(-0.07, 0.12, 0.1 * side, 0.036);
    final s2 = hl(-0.11, 0.17, 0.16 * side, 0.008);
    cap(s0, s1);
    cap(s1, s2);
  }

  // Astas.
  for (final side in const [-1.0, 1.0]) {
    final beam = [for (final b in _beam) hl(b[0], b[1], b[2] * side, b[3])];
    final line = <Offset>[];
    for (var i = 0; i < beam.length; i++) {
      if (i > 0) cap(beam[i - 1], beam[i]);
      line.add(Offset(beam[i].x, beam[i].y));
    }
    antlerLines.add(line);
    for (final tn in _tines) {
      final seg = tn[0].toInt();
      final tt = tn[1];
      final a0 = _beam[seg], a1 = _beam[math.min(seg + 1, _beam.length - 1)];
      final ba = lerpD(a0[0], a1[0], tt), bb = lerpD(a0[1], a1[1], tt), bw = lerpD(a0[2], a1[2], tt);
      final r0 = tn[5];
      final s0 = hl(ba, bb, bw * side, r0);
      final s1 = hl(ba + tn[2] * 0.55, bb + tn[3] * 0.55, (bw + tn[4] * 0.55) * side, r0 * 0.62);
      final s2 = hl(ba + tn[2], bb + tn[3], (bw + tn[4]) * side, r0 * 0.3);
      cap(s0, s1);
      cap(s1, s2);
      antlerLines.add([Offset(s0.x, s0.y), Offset(s1.x, s1.y), Offset(s2.x, s2.y)]);
    }
  }

  // Ojo (del lado visible) y parche claro de la grupa.
  final ea = hl(0.035, 0.03, 0.062, 0.013), eb = hl(0.035, 0.03, -0.062, 0.013);
  final eye = ea.z < eb.z ? ea : eb;
  final thHead = ds.yaw - math.atan((skull.x - cam.cx) / f);
  final rp = pitched(-0.6, 0.86);
  final rump = w3(rp.dx, rp.dy, 0);
  final thRump = ds.yaw - math.atan((rump.x - cam.cx) / f);

  return DeerShape(
    prims: prims,
    antlerLines: antlerLines,
    center: Offset(cxSum / _torso.length, cySum / _torso.length),
    eye: GlowDot(eye.x, eye.y, eye.r, smoothStep(0.35, 0.75, math.sin(thHead).abs())),
    rump: GlowDot(rump.x, rump.y, 0.16 * f / rump.z, math.max(0.0, math.cos(thRump))),
    scale: f / w3(0, 0.9, 0).z,
  );
}
