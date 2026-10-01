// Lingua Splash — línea de tiempo, mundo y cámara.
//
// Todo lo de este archivo es matemática pura (sin dart:ui): la escena es una
// función de (t, hillIndex). Eso permite que el painter sea sin estado y que
// la línea de tiempo se pueda probar con tests unitarios.
//
// Unidades del mundo: 1 u = altura del venado a la cruz.
// Ejes: X derecha, Y arriba, Z hacia el fondo de la pantalla.

import 'dart:math' as math;

const double tau = math.pi * 2;

double clampD(double x, double a, double b) => x < a ? a : (x > b ? b : x);
double lerpD(double a, double b, double t) => a + (b - a) * t;

double smoothStep(double e0, double e1, double x) {
  final t = clampD((x - e0) / (e1 - e0), 0, 1);
  return t * t * (3 - 2 * t);
}

double easeInOutCubic(double t) {
  if (t < 0.5) return 4 * t * t * t;
  final u = -2 * t + 2;
  return 1 - u * u * u / 2;
}

double easeCos(double u) => 0.5 - 0.5 * math.cos(math.pi * clampD(u, 0, 1));

/// Pseudoaleatorio determinista en [0, 1).
double hash01(double n) {
  final s = math.sin(n * 12.9898 + 78.233) * 43758.5453;
  return s - s.floorToDouble();
}

// ───────────────────────── línea de tiempo ─────────────────────────

/// Tiempos de la animación (segundos). Con carga inmediata dura 4.36 s.
abstract final class SplashTimeline {
  static const double firstLanding = 0.12; // plataforma 0 (sin palabra)
  static const double hop = 0.38; // periodo de cada salto
  static const double contact = 0.11; // tiempo apoyado en la plataforma
  static const double bigLeap = 0.54; // salto final a la colina
  static const double settle = 0.42; // frenado sobre la colina
  static const double fadeIn = 0.35;

  /// Plataforma de arranque + 5 palabras.
  static const int minPlatforms = 6;

  /// Cuando termina la carga, la colina aparece a ≥ 3 saltos de distancia.
  static const int lookahead = 3;

  // Relativos al aterrizaje en la colina (LH).
  static const double turnStart = -0.45, turnEnd = 0.45;
  static const double headStart = 0.12, headEnd = 0.85;
  static const double camStart = -0.40, camEnd = 1.00;
  static const double zoomStart = 0.75, zoomEnd = 1.55;
  static const double bloomStart = 0.95, bloomEnd = 1.38;
  static const double fadeStart = 1.30, fadeEnd = 1.80;

  /// Pose fija usada con "reducir movimiento".
  static const double restOffset = 0.74;

  static double landingTime(int k) => firstLanding + k * hop;
  static double hillLanding(int hillIndex) => landingTime(hillIndex - 1) + bigLeap;
  static double endTime(int hillIndex) => hillLanding(hillIndex) + fadeEnd;

  /// Índice de la colina si la carga termina en [t].
  static int decideHillIndex(double t) =>
      math.max(minPlatforms, ((t - firstLanding) / hop).floor() + 1 + lookahead);
}

// ───────────────────────── mundo ─────────────────────────

const double platSpacing = 2.4; // separación entre plataformas
const double runSpeed = platSpacing / SplashTimeline.hop;
const double landOffset = 0.36; // el venado aterriza antes del centro
const double platRx = 1.2; // semiancho lateral (píldora)
const double platRz = 0.62; // semifondo
const double platShift = 0.3; // la píldora se desplaza hacia fuera
const double wordShift = 0.62; // la palabra flota sobre la mitad exterior
const double platThickness = 0.16;

const List<double> _pxs = [-0.6, 0.55, -0.5, 0.6, -0.55];
const List<double> _pys = [0.0, 0.22, -0.08, 0.28, 0.06];

// En Dart `%` con divisor positivo nunca es negativo (k = -1 → 4).
double platX(int k) => _pxs[k % 5];
double platY(int k) => _pys[k % 5];
double platZ(int k) => k * platSpacing;
double platSide(int k) => platX(k) >= 0 ? 1 : -1;

/// Geometría de la colina final (isla flotante).
class HillGeom {
  HillGeom(int hillIndex)
      : k = hillIndex - 1,
        lh = SplashTimeline.hillLanding(hillIndex),
        zHL = platZ(hillIndex - 1) - landOffset + runSpeed * SplashTimeline.bigLeap,
        y = platY(hillIndex - 1) + 0.85 {
    zStop = zHL + runSpeed * SplashTimeline.settle / 2;
  }

  final int k; // última plataforma antes de la colina
  final double lh; // instante del aterrizaje en la colina
  final double zHL; // z donde aterriza
  late final double zStop; // z donde se detiene (cresta)
  final double x = 0.6;
  final double y; // altura de la cresta
}

double pathX(double z, HillGeom? h) {
  if (h != null) {
    final zK = platZ(h.k);
    if (z >= h.zStop) return h.x;
    if (z >= zK) return lerpD(platX(h.k), h.x, easeCos((z - zK) / (h.zStop - zK)));
  }
  final k = (z / platSpacing).floor();
  return lerpD(platX(k), platX(k + 1), easeCos((z - k * platSpacing) / platSpacing));
}

double groundY(double z, HillGeom? h) {
  if (h != null) {
    final zK = platZ(h.k);
    if (z >= h.zStop) return h.y;
    if (z >= zK) return lerpD(platY(h.k), h.y, easeCos((z - zK) / (h.zStop - zK)));
  }
  final k = (z / platSpacing).floor();
  return lerpD(platY(k), platY(k + 1), easeCos((z - k * platSpacing) / platSpacing));
}

// ───────────────────────── venado (estado) ─────────────────────────

class DeerState {
  const DeerState({
    required this.x,
    required this.y,
    required this.z,
    required this.p,
    required this.k,
    required this.landT,
    required this.yaw,
    required this.standW,
    required this.plantW,
    required this.bodyPitch,
    required this.neck,
    required this.head,
  });

  final double x, y, z;
  final double p; // fase de la zancada [0, 1)
  final int k; // última plataforma pisada (k = hill.k + 1 en la colina)
  final double landT; // instante del último aterrizaje
  final double yaw; // 0 = de espaldas a la cámara, + = gira a la derecha
  final double standW; // 0 corriendo → 1 de pie
  final double plantW; // peso de apoyo (pezuñas al suelo)
  final double bodyPitch;
  final double neck; // ángulo del cuello sobre la horizontal
  final double head; // ángulo del hocico sobre la horizontal
}

DeerState deerAt(double t, HillGeom? h) {
  const zStart = -landOffset - runSpeed * SplashTimeline.firstLanding;
  final lk = h != null ? SplashTimeline.landingTime(h.k) : double.infinity;
  final lh = h != null ? h.lh : double.infinity;
  double z, y, p, landT;
  int k;
  var big = false;
  if (t < lh) {
    z = zStart + runSpeed * t;
    double rel;
    if (t < lk) {
      k = ((t - SplashTimeline.firstLanding) / SplashTimeline.hop).floor();
      rel = t - SplashTimeline.landingTime(k);
    } else {
      k = h!.k;
      rel = t - lk;
    }
    big = h != null && k == h.k;
    final flight = (big ? SplashTimeline.bigLeap : SplashTimeline.hop) - SplashTimeline.contact;
    final y0 = platY(k);
    final y1 = big ? h.y : platY(k + 1);
    if (rel < SplashTimeline.contact) {
      p = 0.3 * rel / SplashTimeline.contact;
      y = y0;
    } else {
      final u = (rel - SplashTimeline.contact) / flight;
      p = 0.3 + 0.7 * u;
      y = lerpD(y0, y1, u) + 4 * (big ? 0.95 : 0.42) * u * (1 - u);
    }
    landT = SplashTimeline.landingTime(k);
  } else {
    final u = clampD((t - lh) / SplashTimeline.settle, 0, 1);
    z = h!.zHL + runSpeed * SplashTimeline.settle * (u - u * u / 2);
    y = h.y;
    p = 0;
    k = h.k + 1;
    landT = lh;
  }
  final x = pathX(z, h);
  final slope = (pathX(z + 0.05, h) - pathX(z - 0.05, h)) / 0.1;
  final runYaw = math.atan(slope) * (big ? 1.0 : 0.55);
  final hasHill = h != null;
  final turnW = hasHill ? smoothStep(lh + SplashTimeline.turnStart, lh + SplashTimeline.turnEnd, t) : 0.0;
  final headW = hasHill ? smoothStep(lh + SplashTimeline.headStart, lh + SplashTimeline.headEnd, t) : 0.0;
  final standW = hasHill ? smoothStep(lh - 0.02, lh + 0.45, t) : 0.0;
  final contactW = p < 0.5 ? smoothStep(0, 0.04, p) * (1 - smoothStep(0.26, 0.32, p)) : 0.0;
  return DeerState(
    x: x,
    y: y,
    z: z,
    p: p,
    k: k,
    landT: landT,
    yaw: lerpD(runYaw, 0.95, turnW),
    standW: standW,
    plantW: math.max(contactW, standW),
    bodyPitch: lerpD(0.09 * math.sin(tau * (p - 0.05)), 0.04, standW),
    neck: lerpD(0.62 + 0.07 * math.sin(tau * (p - 0.3)), 1.12, headW),
    head: lerpD(-0.28 + 0.05 * math.sin(tau * (p - 0.1)), 0.78, headW),
  );
}

// ───────────────────────── cámara ─────────────────────────

class Proj {
  const Proj(this.x, this.y, this.z);
  final double x, y; // pantalla (px lógicos)
  final double z; // profundidad en espacio de cámara
}

class SplashCamera {
  SplashCamera({
    required this.x,
    required this.y,
    required this.z,
    required this.pitch,
    required this.f,
    required this.cx,
    required this.cy,
  })  : cp = math.cos(pitch),
        sp = math.sin(pitch);

  final double x, y, z, pitch, f, cx, cy, cp, sp;

  Proj project(double wx, double wy, double wz) {
    final dx = wx - x, dy = wy - y, dz = wz - z;
    final yy = dy * cp - dz * sp;
    final zz = dy * sp + dz * cp;
    return Proj(cx + f * dx / zz, cy - f * yy / zz, zz);
  }

  /// Línea del horizonte (punto de fuga a altura infinita).
  double get horizonY => cy + f * math.tan(pitch);
}

SplashCamera cameraAt(double t, HillGeom? h, DeerState ds, double w, double hh, double s) {
  final e = h != null
      ? easeInOutCubic(clampD(
          (t - h.lh - SplashTimeline.camStart) / (SplashTimeline.camEnd - SplashTimeline.camStart), 0, 1))
      : 0.0;
  final dz = lerpD(3.4, 3.5, e);
  final x = lerpD(0.2 * pathX(ds.z - 0.6, h), ds.x + 0.41, e);
  var y = lerpD(groundY(ds.z - 0.6, h) + 1.3, (h?.y ?? 0.0) + 0.225, e);
  final tau0 = t - ds.landT;
  if (tau0 >= 0 && tau0 < 0.8) {
    // pequeño "golpe" de cámara en cada aterrizaje
    final amp = (h != null && ds.k > h.k) ? 0.1 : 0.06;
    y -= amp * math.exp(-tau0 * 12) * (tau0 * 12);
  }
  return SplashCamera(
    x: x,
    y: y,
    z: ds.z - dz,
    pitch: lerpD(0, 0.2, e),
    f: 1.16 * s,
    cx: w / 2,
    cy: hh * 0.58,
  );
}

/// Luna en el infinito: sólo depende de la rotación de la cámara.
class MoonScreen {
  const MoonScreen(this.x, this.y, this.r);
  final double x, y, r;
}

const double _moonAz = 0.05, _moonEl = 0.524, _moonR = 0.36;

MoonScreen moonScreen(SplashCamera cam, double s) {
  final dx = math.sin(_moonAz) * math.cos(_moonEl);
  final dy = math.sin(_moonEl);
  final dz = math.cos(_moonAz) * math.cos(_moonEl);
  final yy = dy * cam.cp - dz * cam.sp;
  final zz = dy * cam.sp + dz * cam.cp;
  return MoonScreen(cam.cx + cam.f * dx / zz, cam.cy - cam.f * yy / zz, _moonR * s);
}
