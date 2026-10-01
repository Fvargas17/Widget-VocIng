/// Splash animada de Lingua.
///
/// Un venado corre de espaldas a la cámara saltando sobre plataformas con
/// palabras en varios idiomas; al terminar la carga llega a una colina, mira
/// la luna y la cámara entra en ella hasta fundir a [LinguaSplash.endColor].
///
/// Puro Flutter: un `CustomPainter` sin assets ni dependencias.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'src/scene.dart';
import 'src/splash_painter.dart';

export 'src/scene.dart' show SplashTimeline;

class LinguaSplash extends StatefulWidget {
  const LinguaSplash({
    super.key,
    required this.onFinished,
    this.loading,
    this.words = defaultWords,
    this.endColor = const Color(0xFF000000),
    this.fontFamily,
    this.semanticsLabel = 'Cargando',
  });

  static const List<String> defaultWords = ['Hello', 'Bonjour', 'Ciao', 'Hola', 'こんにちは'];

  /// Se llama una sola vez, cuando la pantalla ya es [endColor] uniforme.
  /// Aquí navega a la app (p. ej. con [splashHandoffRoute]).
  final VoidCallback onFinished;

  /// Carga inicial de la app. Mientras no termine, el venado sigue saltando
  /// (las palabras se repiten); al completarse, llega a la colina y cierra.
  /// Si es null o ya terminó, la animación dura 4.36 s.
  /// Si falla, el error se reporta con [FlutterError.reportError] y la splash
  /// termina igualmente: maneja el error en tu pantalla de destino.
  final Future<void>? loading;

  /// Palabras que flotan sobre las plataformas, en orden.
  final List<String> words;

  /// Color en el que termina (y desde el que empieza) la animación.
  /// Debe coincidir con el fondo de la splash nativa y con la primera
  /// pantalla de la app para que el corte sea invisible.
  final Color endColor;

  /// Familia tipográfica de las palabras (la de la app, si quieres).
  final String? fontFamily;

  final String semanticsLabel;

  @override
  State<LinguaSplash> createState() => _LinguaSplashState();
}

class _LinguaSplashState extends State<LinguaSplash> with SingleTickerProviderStateMixin {
  // Modo "reducir movimiento": pose final fija con fundidos.
  static const double _staticFadeIn = 0.3, _staticHold = 0.5, _staticFadeOut = 0.45;

  late final Ticker _ticker;
  final ValueNotifier<SplashFrame> _frame = ValueNotifier(const SplashFrame(time: 0));
  late WordGlyphCache _glyphs;

  bool _ready = false;
  bool _finished = false;
  bool? _reducedMotion;
  int? _hillIndex;
  double _hillRevealAt = 0;
  double? _readyAt;

  @override
  void initState() {
    super.initState();
    _glyphs = WordGlyphCache(fontFamily: widget.fontFamily);
    _ticker = createTicker(_onTick);
    final loading = widget.loading;
    if (loading == null) {
      _ready = true;
    } else {
      unawaited(loading.then<void>(
        (_) {
          _ready = true;
        },
        onError: (Object error, StackTrace stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'lingua_splash',
            context: ErrorDescription('mientras se esperaba la carga inicial'),
          ));
          _ready = true;
        },
      ));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se decide una vez: no cambiamos de modo a mitad de la animación.
    _reducedMotion ??= MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_ticker.isActive && !_finished) _ticker.start();
  }

  @override
  void didUpdateWidget(LinguaSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontFamily != widget.fontFamily) {
      _glyphs.dispose();
      _glyphs = WordGlyphCache(fontFamily: widget.fontFamily);
    }
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (_reducedMotion ?? false) {
      _tickStatic(t);
      return;
    }
    if (_hillIndex == null && _ready) {
      _hillIndex = SplashTimeline.decideHillIndex(t);
      _hillRevealAt = t;
    }
    final hill = _hillIndex;
    final end = hill == null ? double.infinity : SplashTimeline.endTime(hill);
    _frame.value = SplashFrame(time: math.min(t, end), hillIndex: hill, hillRevealAt: _hillRevealAt);
    if (t >= end) _finish();
  }

  void _tickStatic(double t) {
    if (_ready && _readyAt == null) _readyAt = math.max(t, _staticFadeIn + _staticHold);
    final readyAt = _readyAt;
    var overlay = 1 - smoothStep(0, _staticFadeIn, t);
    if (readyAt != null) overlay = math.max(overlay, smoothStep(readyAt, readyAt + _staticFadeOut, t));
    const hill = SplashTimeline.minPlatforms;
    _frame.value = SplashFrame(
      time: SplashTimeline.hillLanding(hill) + SplashTimeline.restOffset,
      hillIndex: hill,
      hillRevealAt: -10.0,
      overlay: overlay,
    );
    if (readyAt != null && t >= readyAt + _staticFadeOut) _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _ticker.stop();
    widget.onFinished();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _glyphs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      container: true,
      child: ColoredBox(
        color: widget.endColor,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: SplashPainter(
              frame: _frame,
              words: widget.words,
              glyphs: _glyphs,
              endColor: widget.endColor,
            ),
            isComplex: true,
            willChange: true,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Ruta para salir de la splash: la pantalla nueva aparece desde [color]
/// (el mismo `endColor`), así que el relevo no tiene saltos.
///
/// ```dart
/// Navigator.of(context).pushReplacement(splashHandoffRoute((_) => const HomeScreen()));
/// ```
Route<T> splashHandoffRoute<T>(
  WidgetBuilder builder, {
  Color color = const Color(0xFF000000),
  Duration duration = const Duration(milliseconds: 450),
}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) => ColoredBox(
      color: color,
      child: FadeTransition(
        opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}
