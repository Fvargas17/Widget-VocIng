// Lingua Splash — CustomPainter.
//
// Dibuja la escena completa a partir de un [SplashFrame]. No guarda estado
// entre frames (salvo la caché de texto): todo se deriva de `time`.
//
// Capas, de atrás hacia delante, cada una con su factor de zoom final:
//   cielo ×1.7 · estrellas ×0.5 · luna ×1 · mundo ×1.7 · motas ×2
// El factor distinto por capa da paralaje durante el zoom a la luna.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'deer_rig.dart';
import 'scene.dart';

/// Estado mínimo para pintar un frame.
@immutable
class SplashFrame {
  const SplashFrame({
    required this.time,
    this.hillIndex,
    this.hillRevealAt = 0,
    this.overlay = 0,
  });

  /// Segundos desde el inicio de la animación.
  final double time;

  /// Plataforma tras la cual aparece la colina; null mientras se carga.
  final int? hillIndex;

  /// Instante en que se decidió la colina (para que aparezca con fundido).
  final double hillRevealAt;

  /// Velo extra del color final (0–1); lo usa el modo "reducir movimiento".
  final double overlay;
}

// ───────────────────────── paleta ─────────────────────────

typedef _Rgb = (int, int, int);

const _Rgb _skyTop = (3, 4, 12);
const _Rgb _skyMid = (10, 14, 44);
const _Rgb _skyLow = (30, 21, 72);
const _Rgb _horizon = (52, 30, 98);
const _Rgb _abyssTop = (26, 18, 66);
const _Rgb _abyssMid = (11, 9, 34);
const _Rgb _abyssBot = (2, 2, 8);
const _Rgb _ridgeFar = (22, 20, 62);
const _Rgb _ridgeNear = (10, 10, 34);
const _Rgb _hill = (8, 10, 30);
const _Rgb _hillBot = (3, 4, 12);
const _Rgb _rim = (125, 249, 255);
const _Rgb _rimHot = (222, 255, 255);
const _Rgb _rimCool = (44, 62, 150);
const _Rgb _bodyLit = (34, 78, 120);
const _Rgb _body = (13, 20, 52);
const _Rgb _bodyDark = (4, 6, 20);
const _Rgb _moonCore = (246, 255, 253);
const _Rgb _moonMid = (214, 247, 241);
const _Rgb _moonEdge = (150, 226, 226);
const _Rgb _moonLimb = (118, 206, 218);
const _Rgb _moonHalo = (140, 250, 240);
const _Rgb _moonHalo2 = (110, 150, 255);
const _Rgb _maria = (92, 150, 172);
const _Rgb _bloom = (200, 255, 246);
const _Rgb _word = (236, 254, 255);

const List<_Rgb> _hues = [
  (92, 242, 255), // cian
  (169, 139, 255), // violeta
  (255, 122, 217), // magenta
  (108, 255, 196), // menta
  (120, 190, 255), // azul
];

Color _c(_Rgb c, [double a = 1]) => Color.fromRGBO(c.$1, c.$2, c.$3, clampD(a, 0, 1));

// Mares y cráteres de la luna: [dx, dy, radio, alfa] relativos al radio.
const List<List<double>> _mariaSpots = [
  [-0.3, -0.2, 0.34, 0.3],
  [0.26, -0.36, 0.22, 0.24],
  [0.1, 0.14, 0.28, 0.26],
  [-0.16, 0.44, 0.2, 0.2],
  [0.5, 0.12, 0.15, 0.18],
  [-0.56, 0.18, 0.16, 0.14],
  [-0.02, -0.08, 0.16, 0.12],
];
const List<List<double>> _craters = [
  [0.38, 0.52, 0.06],
  [-0.42, -0.5, 0.05],
  [0.05, -0.6, 0.04],
  [-0.58, -0.1, 0.035],
  [0.62, -0.18, 0.04],
  [-0.2, 0.2, 0.03],
];

// Isla flotante (colina final).
const double _islandW = 3.4;
const List<List<double>> _islandUnder = [
  [3.4, -1.75], [2.7, -2.3], [1.9, -2.7], [1.2, -3.3], [0.55, -3.6], [0.1, -4.2],
  [-0.45, -3.5], [-1.2, -3.1], [-2.1, -2.6], [-2.9, -2.1], [-3.4, -1.75],
];

double _hillDrop(double dx, double side) {
  final a = math.min(dx.abs(), 0.75);
  final q = math.max(0.0, dx.abs() - 0.75);
  return math.min(9.0, 0.02 * a * a + side * (0.3 * q + 0.12 * q * q));
}

// ───────────────────────── caché de texto ─────────────────────────

/// Palabras maquetadas una sola vez (48 px) y escaladas con el canvas.
class WordGlyphCache {
  WordGlyphCache({this.fontFamily});

  final String? fontFamily;
  final Map<String, TextPainter> _cache = {};

  TextPainter glyph(String word, int hueIndex) {
    return _cache.putIfAbsent('$hueIndex|$word', () {
      final glow = _hues[hueIndex];
      return TextPainter(
        text: TextSpan(
          text: word,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 48,
            height: 1.0,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.0,
            color: _c(_word),
            shadows: [
              Shadow(color: _c(glow, 0.95), blurRadius: 28),
              Shadow(color: _c(glow, 0.9), blurRadius: 8),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      )..layout();
    });
  }

  void dispose() {
    for (final p in _cache.values) {
      p.dispose();
    }
    _cache.clear();
  }
}

// ───────────────────────── painter ─────────────────────────

class SplashPainter extends CustomPainter {
  SplashPainter({
    required this.frame,
    required this.words,
    required this.glyphs,
    required this.endColor,
  }) : super(repaint: frame);

  final ValueListenable<SplashFrame> frame;
  final List<String> words;
  final WordGlyphCache glyphs;
  final Color endColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _Scene(canvas, size, frame.value, words, glyphs, endColor).render();
    canvas.restore();
  }

  @override
  bool shouldRepaint(SplashPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      !listEquals(oldDelegate.words, words) ||
      oldDelegate.glyphs != glyphs ||
      oldDelegate.endColor != endColor;
}

/// Un frame: calcula cámara, venado y luna una vez y pinta todas las capas.
class _Scene {
  _Scene(this.canvas, this.size, this.fr, this.words, this.glyphs, this.endColor)
      : w = size.width,
        h = size.height,
        t = fr.time,
        hill = fr.hillIndex == null ? null : HillGeom(fr.hillIndex!) {
    s = math.min(w, h * 0.52);
    k = s / 390;
    ds = deerAt(t, hill);
    cam = cameraAt(t, hill, ds, w, h, s);
    horizonY = cam.horizonY;
    moon = moonScreen(cam, s);
  }

  final Canvas canvas;
  final Size size;
  final SplashFrame fr;
  final List<String> words;
  final WordGlyphCache glyphs;
  final Color endColor;
  final double w, h, t;
  final HillGeom? hill;
  late final double s, k, horizonY;
  late final DeerState ds;
  late final SplashCamera cam;
  late final MoonScreen moon;

  // ───────────── utilidades ─────────────

  void _radial(Offset c, double r, List<(double, _Rgb, double)> stops, {bool plus = false}) {
    if (r <= 0) return;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        c,
        r,
        [for (final st in stops) _c(st.$2, st.$3)],
        [for (final st in stops) st.$1],
      );
    if (plus) paint.blendMode = BlendMode.plus;
    canvas.drawCircle(c, r, paint);
  }

  Path _polysPath(List<List<Offset>> polys) {
    final path = Path();
    for (final p in polys) {
      path.addPolygon(p, true);
    }
    return path;
  }

  Color _end(double a) => endColor.withAlpha((255 * clampD(a, 0, 1)).round());

  // ───────────── frame ─────────────

  void render() {
    final hl = hill;
    final lh = hl?.lh ?? double.infinity;
    final zu = hl != null
        ? clampD((t - lh - SplashTimeline.zoomStart) / (SplashTimeline.zoomEnd - SplashTimeline.zoomStart), 0, 1)
        : 0.0;
    final zs = math.pow(10, math.pow(zu, 2.2)).toDouble();
    final tc = easeInOutCubic(zu);
    final tx = lerpD(moon.x, w / 2, tc), ty = lerpD(moon.y, h / 2, tc);

    void layer(double power, void Function() draw) {
      final sc = math.pow(zs, power).toDouble();
      canvas
        ..save()
        ..translate(tx, ty)
        ..scale(sc, sc)
        ..translate(-moon.x, -moon.y);
      draw();
      canvas.restore();
    }

    final screen = Offset.zero & size;
    canvas.drawRect(screen, Paint()..color = _c(_skyTop));
    layer(1.7, _drawSky);
    layer(0.5, _drawStars);
    layer(1.0, _drawMoon);
    layer(1.7, () => _drawWorld(zu));
    if (zu < 1) layer(2.0, () => _drawMotes(1 - smoothStep(0, 0.6, zu)));

    // Resplandor de la luna que crece con el zoom → fundido al color final.
    if (hl != null) {
      final b = smoothStep(lh + SplashTimeline.bloomStart, lh + SplashTimeline.bloomEnd, t);
      if (b > 0) {
        final br = math.max(moon.r * zs * 1.25, 1.0);
        canvas.drawRect(
          screen,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(tx, ty),
              br,
              [_c(_bloom, 0.7 * b), _c(_bloom, 0.45 * b), _c(_bloom, 0.0)],
              const [0.0, 0.6, 1.0],
            ),
        );
      }
      final f = easeInOutCubic(clampD(
          (t - lh - SplashTimeline.fadeStart) / (SplashTimeline.fadeEnd - SplashTimeline.fadeStart), 0, 1));
      if (f > 0) canvas.drawRect(screen, Paint()..color = _end(f));
    }
    final fi = math.max(1 - smoothStep(0, SplashTimeline.fadeIn, t), fr.overlay);
    if (fi > 0) canvas.drawRect(screen, Paint()..color = _end(fi));
  }

  // ───────────── cielo ─────────────

  void _drawSky() {
    final top = horizonY - h * 1.6;
    canvas.drawRect(
      Rect.fromLTRB(-w, top - h, w * 2, horizonY + 1),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, horizonY),
          [_c(_skyTop), _c(_skyMid), _c(_skyLow), _c(_horizon)],
          const [0.0, 0.55, 0.86, 1.0],
        ),
    );
  }

  void _drawStars() {
    final shift = horizonY - cam.cy;
    final paint = Paint();
    for (var i = 0; i < 90; i++) {
      final u = hash01(i * 3.1), v = hash01(i * 7.7 + 1.3);
      final y = cam.cy + shift - h * (0.1 + 0.8 * v);
      final r = (0.45 + 1.15 * hash01(i * 1.9 + 3)) * k;
      final tw = 0.5 + 0.5 * math.sin(t * (1.4 + 2.2 * hash01(i * 5.3)) + i);
      final a = (0.25 + 0.75 * tw) * smoothStep(horizonY - h * 0.02, horizonY - h * 0.14, y);
      if (a <= 0.01) continue;
      paint.color = _c(i % 7 == 0 ? _hues[1] : _moonCore, a * 0.85);
      canvas.drawCircle(Offset(u * w, y), r, paint);
    }
  }

  void _drawMoon() {
    final c = Offset(moon.x, moon.y);
    final r = moon.r;
    _radial(c, r * 3.4, const [
      (0.0, _moonHalo, 0.3),
      (0.3, _moonHalo, 0.16),
      (0.62, _moonHalo2, 0.06),
      (1.0, _moonHalo2, 0.0),
    ]);
    _radial(c, r * 1.45, const [
      (0.6, _moonCore, 0.55),
      (0.7, _moonHalo, 0.28),
      (1.0, _moonHalo, 0.0),
    ]);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [_c(_moonCore), _c(_moonMid), _c(_moonEdge), _c(_moonLimb)],
          const [0.0, 0.55, 0.9, 1.0],
          TileMode.clamp,
          null,
          Offset(c.dx - r * 0.22, c.dy - r * 0.25),
        ),
    );
    // Mares y cráteres con degradados: escalan limpios durante el zoom.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    for (final m in _mariaSpots) {
      final a = m[3];
      _radial(Offset(c.dx + m[0] * r, c.dy + m[1] * r), m[2] * r, [
        (0.0, _maria, a),
        (0.6, _maria, a * 0.6),
        (1.0, _maria, 0.0),
      ]);
    }
    for (final cr in _craters) {
      final x = c.dx + cr[0] * r, y = c.dy + cr[1] * r, rr = cr[2] * r;
      _radial(Offset(x + rr * 0.15, y + rr * 0.15), rr, const [
        (0.0, _maria, 0.0),
        (0.7, _maria, 0.22),
        (1.0, _maria, 0.0),
      ]);
      _radial(Offset(x - rr * 0.2, y - rr * 0.2), rr * 0.7, const [
        (0.0, _moonCore, 0.3),
        (1.0, _moonCore, 0.0),
      ]);
    }
    canvas.restore();
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * k
        ..color = _c(_moonCore, 0.7),
    );
  }

  // ───────────── mundo ─────────────

  void _drawWorld(double zu) {
    _drawAbyss();
    _drawRidges();
    final hl = hill;
    if (hl != null) {
      final reveal = smoothStep(fr.hillRevealAt, fr.hillRevealAt + 0.6, t);
      final a = reveal * (0.35 + 0.65 * smoothStep(36, 12, hl.zStop - cam.z));
      if (a > 0.01) _drawIsland(hl, a);
    }

    // Plataformas de lejos a cerca; el venado se intercala por profundidad.
    final kMax = hl != null ? math.min(hl.k, ds.k + 6) : ds.k + 6;
    final behind = <int>[];
    for (var i = kMax; i >= -1; i--) {
      if (platZ(i) > ds.z - 0.5) {
        _drawPlatform(i);
      } else {
        behind.add(i);
      }
    }
    // Al final del zoom el venado ya salió de cuadro: no se dibuja.
    if (zu < 0.85) _drawDeer(buildDeer(ds, cam), glow: zu < 0.7);
    behind.forEach(_drawPlatform);

    // Partículas de luz residual.
    for (var i = math.max(0, ds.k - 3); i <= math.min(kMax, ds.k); i++) {
      final lt = SplashTimeline.landingTime(i);
      final hue = _hues[i % 5];
      _drawBurst(pathX(platZ(i) - landOffset, hl), platY(i) + 0.02, platZ(i) - 0.05, lt, i + 1, hue, 18, 1, 0.5);
      if (i >= 1) {
        _drawBurst(platX(i) + platSide(i) * wordShift, platY(i) + 0.42, platZ(i), lt - 0.04, i + 50, hue, 16, 0.7, 1.1);
      }
    }
    if (hl != null && t >= hl.lh) {
      _drawBurst(pathX(hl.zHL, hl), hl.y + 0.02, hl.zHL + 0.3, hl.lh, 99, _rim, 34, 1.3, 0.8);
    }
  }

  void _drawAbyss() {
    canvas.drawRect(
      Rect.fromLTWH(-w, horizonY, w * 3, h * 2.2),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizonY),
          Offset(0, horizonY + h * 0.7),
          [_c(_abyssTop), _c(_abyssMid), _c(_abyssBot)],
          const [0.0, 0.3, 1.0],
        ),
    );
  }

  void _drawRidges() {
    final shiftFar = cam.x * s * 0.012;
    final shiftNear = cam.x * s * 0.03;
    final step = 6 * k;

    // Cordillera lejana.
    final far = Path()..moveTo(-w, horizonY + 2);
    for (var x = -w; x <= 2 * w; x += step) {
      final u = (x + shiftFar) / s;
      final hh = 0.11 *
          s *
          (0.55 + 0.25 * math.sin(u * 2.1 + 1.0) + 0.14 * math.sin(u * 5.3 + 2.0) + 0.06 * math.sin(u * 13.7 + 3.0));
      far.lineTo(x, horizonY - hh);
    }
    far
      ..lineTo(2 * w, horizonY + 2)
      ..close();
    canvas.drawPath(far, Paint()..color = _c(_ridgeFar));

    // Bruma iluminada por la luna.
    canvas.save();
    canvas.translate(moon.x, horizonY);
    canvas.scale(1, 0.22);
    _radial(Offset.zero, w * 0.95, const [
      (0.0, _moonHalo, 0.26),
      (0.45, _moonHalo2, 0.1),
      (1.0, _moonHalo2, 0.0),
    ]);
    canvas.restore();

    // Cordillera cercana con pinos.
    double ridgeAt(double x) {
      final u = (x + shiftNear) / s;
      return horizonY - 0.055 * s * (0.5 + 0.3 * math.sin(u * 1.7 + 4.0) + 0.2 * math.sin(u * 4.1 + 1.0));
    }

    final near = Path()..moveTo(-w, horizonY + 2);
    for (var x = -w; x <= 2 * w; x += step) {
      near.lineTo(x, ridgeAt(x));
    }
    near
      ..lineTo(2 * w, horizonY + 2)
      ..close();
    final treeStep = 7 * k;
    final shiftMod = shiftNear.remainder(treeStep);
    for (var i = 0; i < 3 * w / treeStep; i++) {
      if (hash01(i * 9.1) < 0.35) continue;
      final x = -w + i * treeStep + hash01(i * 1.7) * 4 * k - shiftMod;
      final hgt = (0.012 + 0.032 * hash01(i * 3.3 + 0.5)) * s;
      final base = ridgeAt(x) + 1;
      final tw = hgt * 0.32;
      near
        ..moveTo(x - tw, base)
        ..lineTo(x, base - hgt)
        ..lineTo(x + tw, base)
        ..close();
    }
    canvas.drawPath(near, Paint()..color = _c(_ridgeNear));

    // Velo de niebla sobre el horizonte.
    canvas.drawRect(
      Rect.fromLTWH(-w, horizonY - 0.08 * s, 3 * w, 0.18 * s),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizonY - 0.08 * s),
          Offset(0, horizonY + 0.1 * s),
          [_c(_abyssTop, 0.0), _c(_horizon, 0.35), _c(_abyssTop, 0.0)],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  void _drawIsland(HillGeom hl, double alpha) {
    final z = hl.zStop, cx = hl.x, cy = hl.y;
    Offset pt(double dx, double dy) {
      final p = cam.project(cx + dx, cy + dy, z);
      return Offset(p.x, p.y);
    }

    final top = <Offset>[];
    for (var dx = -_islandW; dx <= _islandW + 0.001; dx += 0.2) {
      top.add(pt(dx, -_hillDrop(dx, dx < 0 ? 1.0 : 0.85)));
    }
    final under = [for (final u in _islandUnder) pt(u[0], u[1])];
    final scale = cam.f / (z - cam.z);

    // Resplandor bajo la isla.
    final g0 = cam.project(cx, cy - 3.0, z);
    canvas.save();
    canvas.translate(g0.x, g0.y);
    canvas.scale(1, 0.75);
    _radial(Offset.zero, 2.8 * scale, [
      (0.0, _rim, 0.12 * alpha),
      (0.5, _rimCool, 0.06 * alpha),
      (1.0, _rimCool, 0.0),
    ], plus: true);
    canvas.restore();

    // Cuerpo.
    final crest = cam.project(cx, cy, z).y;
    final body = Path()..addPolygon([...top, ...under], true);
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, crest),
          Offset(0, crest + 4.2 * scale),
          [_c(_hill, alpha), _c(_hillBot, alpha), _c(_abyssMid, alpha)],
          const [0.0, 0.5, 1.0],
        ),
    );

    // Aristas inferiores (luz fría).
    canvas.drawPath(
      Path()..addPolygon(under, false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, 0.012 * scale)
        ..color = _c(_rimCool, 0.55 * alpha),
    );

    // Hierba en la cima.
    final grass = Path();
    for (var i = 0; i < 18; i++) {
      final dx = -1.8 + 3.8 * hash01(i * 4.7 + 0.3);
      final gh = 0.06 + 0.13 * hash01(i * 2.9 + 1.1);
      final lean = (hash01(i * 6.1) - 0.5) * 0.12;
      final by = cy - _hillDrop(dx, dx < 0 ? 1.0 : 0.85);
      final b0 = cam.project(cx + dx - 0.022, by + 0.01, z);
      final b1 = cam.project(cx + dx + 0.022, by + 0.01, z);
      final tp = cam.project(cx + dx + lean, by + gh, z);
      grass
        ..moveTo(b0.x, b0.y)
        ..quadraticBezierTo((b0.x + tp.x) / 2 - 0.01 * scale, (b0.y + tp.y) / 2, tp.x, tp.y)
        ..quadraticBezierTo((b1.x + tp.x) / 2 + 0.005 * scale, (b1.y + tp.y) / 2, b1.x, b1.y)
        ..close();
    }
    canvas.drawPath(grass, Paint()..color = _c(_hill, alpha));

    // Cresta a contraluz.
    final crestPath = Path()..addPolygon(top, false);
    final crestShader = ui.Gradient.linear(
      Offset(moon.x - moon.r * 2.2, 0),
      Offset(moon.x + moon.r * 2.2, 0),
      [_c(_rim, 0.15 * alpha), _c(_rimHot, 0.95 * alpha), _c(_rim, 0.15 * alpha)],
      const [0.0, 0.5, 1.0],
    );
    canvas.drawPath(
      crestPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * k
        ..strokeJoin = StrokeJoin.round
        ..color = _c(_rim, 0.8 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * k),
    );
    canvas.drawPath(
      crestPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * k
        ..strokeJoin = StrokeJoin.round
        ..shader = crestShader,
    );
  }

  void _drawPlatform(int idx) {
    final landT = SplashTimeline.landingTime(idx);
    final bob = 0.05 * math.sin(t * 2.2 + idx * 1.7) * (1 - smoothStep(landT - 0.6, landT - 0.1, t));
    final sgn = platSide(idx);
    final x = platX(idx) + sgn * platShift, y = platY(idx) + bob, z = platZ(idx);
    final c = cam.project(x, y, z);
    if (c.z - platRz < 0.45) return;
    final nr = cam.project(x, y, z - platRz);
    final fa = cam.project(x, y, z + platRz);
    final sd = cam.project(x + platRx, y, z);
    final bt = cam.project(x, y - platThickness, z);
    final ex = c.x, ey = (nr.y + fa.y) / 2;
    final rx = sd.x - c.x;
    final ry = math.max((nr.y - fa.y).abs() / 2, rx * 0.06);
    final dy = bt.y - c.y;
    final fog = smoothStep(28, 9, c.z);
    final col = _hues[idx % 5];
    final act = t < landT ? 0.8 : 0.5 + 0.75 * math.exp(-(t - landT) * 5);
    final near = smoothStep(1.9, 3.0, c.z);
    final used = 1 - smoothStep(landT + 0.12, landT + 0.34, t);
    final a = (0.2 + 0.8 * fog) * act * near * used;
    final scale = cam.f / c.z;
    if (rx <= 0) return;

    if (a > 0.004) {
      // Resplandor inferior: la plataforma "flota".
      canvas.save();
      canvas.translate(ex, ey + dy + ry * 0.6);
      canvas.scale(1, 0.42);
      _radial(Offset.zero, rx * 1.35, [(0.0, col, 0.3 * a), (0.5, col, 0.1 * a), (1.0, col, 0.0)], plus: true);
      canvas.restore();

      // Canto.
      final topRect = Rect.fromCenter(center: Offset(ex, ey), width: rx * 2, height: ry * 2);
      final botRect = Rect.fromCenter(center: Offset(ex, ey + dy), width: rx * 2, height: ry * 2);
      final band = Path()
        ..moveTo(ex + rx, ey)
        ..arcTo(topRect, 0, math.pi, false)
        ..lineTo(ex - rx, ey + dy)
        ..arcTo(botRect, math.pi, -math.pi, false)
        ..close();
      canvas.drawPath(
        band,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, ey),
            Offset(0, ey + dy + ry),
            [_c(col, 0.55 * a), _c(col, 0.12 * a)],
          ),
      );

      // Cara superior.
      canvas.save();
      canvas.translate(ex, ey);
      canvas.scale(1, ry / rx);
      _radial(Offset.zero, rx, [(0.0, col, 0.42 * a), (0.7, col, 0.2 * a), (1.0, col, 0.38 * a)]);
      canvas.restore();

      // Borde brillante + anillo interior.
      final rimW = math.max(1.0, 0.022 * scale);
      canvas.drawOval(
        topRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rimW
          ..color = _c(col, 0.9 * a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, 0.06 * scale)),
      );
      canvas.drawOval(
        topRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rimW
          ..color = _c(col, 0.95 * a),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex, ey), width: rx * 1.24, height: ry * 1.24),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, 0.01 * scale)
          ..color = _c(col, 0.38 * a),
      );

      // Puntos que orbitan el borde.
      final dot = Paint()..color = _c(_word, 0.8 * a);
      final dr = math.max(0.6, 0.012 * scale);
      for (var i = 0; i < 6; i++) {
        final ang = t * 0.8 + i * tau / 6 + idx;
        canvas.drawCircle(Offset(ex + math.cos(ang) * rx * 0.81, ey + math.sin(ang) * ry * 0.81), dr, dot);
      }
    }

    // Onda de aterrizaje.
    final lu = (t - landT) / 0.45;
    if (lu > 0 && lu < 1) {
      final sc = 1 + lu * 0.55;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex, ey), width: rx * 2 * sc, height: ry * 2 * sc),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, 0.03 * scale * (1 - lu))
          ..color = _c(_word, 0.85 * (1 - lu) * (1 - lu) * near),
      );
    }

    // Palabra flotante (la plataforma 0 es el arranque y no lleva).
    if (idx < 1 || words.isEmpty) return;
    final wu = (t - (landT - 0.06)) / 0.2;
    if (wu >= 1) return;
    final burst = wu > 0 ? wu : 0.0;
    final wa = smoothStep(10.4, 8.2, c.z) * (1 - burst) * (1 - burst);
    if (wa <= 0.01) return;
    final wp = cam.project(platX(idx) + sgn * wordShift, y + 0.42 + 0.04 * math.sin(t * 2 + idx), z);
    final ws = 0.36 * scale / 48 * (1 + 0.15 * burst);
    final tp = glyphs.glyph(words[(idx - 1) % words.length], idx % 5);
    final halfW = tp.width * ws / 2 + 12 * k;
    final wx = clampD(wp.x, halfW, math.max(halfW, w - halfW));
    canvas.save();
    canvas.translate(wx, wp.y);
    canvas.scale(ws, ws);
    canvas.saveLayer(
      Rect.fromCenter(center: Offset.zero, width: tp.width + 140, height: tp.height + 140),
      Paint()..color = Color.fromRGBO(0, 0, 0, wa),
    );
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
    canvas.restore();
  }

  /// Partículas deterministas: posición = f(tiempo desde el impacto).
  void _drawBurst(double ox, double oy, double oz, double t0, int seed, _Rgb col, int count, double power,
      double spreadX) {
    final tau0 = t - t0;
    if (tau0 < 0 || tau0 > 1.4) return;
    final glow = Paint()..blendMode = BlendMode.plus;
    final core = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < count; i++) {
      final h1 = hash01(seed * 37.1 + i * 1.31), h2 = hash01(seed * 11.7 + i * 2.17);
      final h3 = hash01(seed * 5.3 + i * 3.71), h4 = hash01(seed * 23.9 + i * 0.73);
      final life = 0.55 + 0.7 * h4;
      if (tau0 > life) continue;
      final ang = h1 * tau;
      final sp = (0.35 + 1.1 * h2) * power;
      final up = (0.5 + 1.7 * h3) * power;
      final p = cam.project(
        ox + (h2 - 0.5) * spreadX + math.cos(ang) * sp * tau0,
        oy + up * tau0 - 0.9 * tau0 * tau0,
        oz + math.sin(ang) * sp * tau0 * 0.6,
      );
      if (p.z < 0.3) continue;
      final r = math.min((0.012 + 0.03 * h1) * cam.f / p.z, 0.012 * cam.f);
      final fade = 1 - tau0 / life;
      final a = fade * math.sqrt(fade) * smoothStep(1.8, 3.0, p.z);
      if (a <= 0.01) continue;
      glow.color = _c(col, 0.2 * a);
      core.color = _c(_word, 0.9 * a);
      final o = Offset(p.x, p.y);
      canvas.drawCircle(o, r * 2.6, glow);
      canvas.drawCircle(o, r, core);
    }
  }

  void _drawDeer(DeerShape deer, {required bool glow}) {
    final outer = _polysPath(deer.polys(0));
    final mid = _polysPath(deer.polys(1.3 * k));
    final core = _polysPath(deer.polys(2.8 * k));
    final dc = deer.center;
    var vx = moon.x - dc.dx, vy = moon.y - dc.dy;
    var vl = math.sqrt(vx * vx + vy * vy);
    if (vl == 0) vl = 1;
    vx /= vl;
    vy /= vl;
    final r = deer.scale * 1.1;
    final p0 = Offset(dc.dx + vx * r, dc.dy + vy * r);
    final p1 = Offset(dc.dx - vx * r, dc.dy - vy * r);
    final rim = ui.Gradient.linear(p0, p1, [_c(_rimHot), _c(_rim), _c(_rimCool)], const [0.0, 0.45, 1.0]);

    // Halo exterior difuso + contorno. El blur se omite cuando el zoom ya es
    // grande: su sigma escala con la transformación y sería caro.
    if (glow) {
      canvas.drawPath(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * k
          ..strokeJoin = StrokeJoin.round
          ..color = _c(_rim, 0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * k),
      );
    }
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * k
        ..strokeJoin = StrokeJoin.round
        ..shader = rim,
    );
    // Banda de rim light → transición → cuerpo.
    canvas.drawPath(outer, Paint()..shader = rim);
    canvas.drawPath(mid, Paint()..shader = ui.Gradient.linear(p0, p1, [_c(_bodyLit), _c(_body)]));
    canvas.drawPath(
      core,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, dc.dy - r),
          Offset(0, dc.dy + r),
          [_c(_body), _c(_bodyDark)],
        ),
    );
    // Parche claro de la grupa (visible de espaldas).
    if (deer.rump.alpha > 0.05) {
      canvas.save();
      canvas.clipPath(core);
      _radial(Offset(deer.rump.x, deer.rump.y), deer.rump.r, [(0.0, _rim, 0.2 * deer.rump.alpha), (1.0, _rim, 0.0)]);
      canvas.restore();
    }
    // Núcleo luminoso de las astas.
    final antler = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _c(_rimHot, 0.35);
    for (final l in deer.antlerLines) {
      canvas.drawPath(Path()..addPolygon(l, false), antler);
    }
    // Ojo.
    if (deer.eye.alpha > 0.01) {
      final ea = deer.eye.alpha;
      _radial(Offset(deer.eye.x, deer.eye.y), deer.eye.r * 3, [
        (0.0, _rimHot, ea),
        (0.35, _rim, 0.6 * ea),
        (1.0, _rim, 0.0),
      ]);
    }
  }

  void _drawMotes(double fade) {
    final glow = Paint()..blendMode = BlendMode.plus;
    final core = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < 34; i++) {
      final u = hash01(i * 11.1), v = hash01(i * 5.7 + 2.0);
      final sp = 0.02 + 0.05 * hash01(i * 2.3);
      final ph = hash01(i * 9.9) * tau;
      final x = u * w + math.sin(t * 0.8 + ph) * 12 * k;
      final y = ((v - t * sp) % 1.0) * h;
      final r = (0.8 + 1.6 * hash01(i * 4.4)) * k;
      final sn = math.sin(t * 2.6 + ph);
      final a = (0.15 + 0.45 * sn * sn) * fade;
      glow.color = _c(_hues[i % 5], a * 0.35);
      core.color = _c(_word, a);
      canvas.drawCircle(Offset(x, y), r * 3, glow);
      canvas.drawCircle(Offset(x, y), r * 0.8, core);
    }
  }
}
