import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../pets/pet_catalog.dart';
import '../services/card_density_service.dart';
import '../services/pet_service.dart';

/// Desactiva el paseo (`AnimationController.repeat`) y la suscripción al
/// acelerómetro. **No es opcional en tests**: un controller en `repeat()`
/// nunca "asienta", así que `pumpAndSettle()` colgaría indefinidamente si
/// `HomeScreen` incluye esta mascota por defecto — mismo motivo que
/// `sound_service.debugDisableSounds`.
@visibleForTesting
bool debugDisablePetMotion = false;

/// Mascota que camina de lado a lado debajo de la tarjeta en `HomeScreen`,
/// se inclina con la gravedad real del teléfono y celebra cada vez que
/// [celebrationSignal] cambia (una palabra recién marcada como aprendida).
///
/// El tamaño de la mascota es intencionalmente el de un botón: es un
/// distintivo de marca, no un elemento con el que se interactúe.
class PetCompanion extends StatefulWidget {
  const PetCompanion({
    super.key,
    required this.pet,
    required this.celebrationSignal,
    required this.density,
  });

  final Pet pet;

  /// Cualquier cambio de valor dispara la animación de celebración. Quien
  /// instancia el widget solo necesita incrementar un contador al marcar una
  /// palabra como aprendida.
  final int celebrationSignal;

  /// Mismo valor que recibe `VocabularyCard`: el margen lateral de la caja
  /// de la mascota debe coincidir con el de la tarjeta de arriba, para que
  /// ambas se vean del mismo ancho.
  final CardDensity density;

  @override
  State<PetCompanion> createState() => _PetCompanionState();
}

class _PetCompanionState extends State<PetCompanion>
    with TickerProviderStateMixin {
  static const double _emojiSize = 32;
  static const double _height = _emojiSize * 1.8;

  // Velocidad de paseo a 0.88 de la original (2600ms): a más duración, más
  // lento el recorrido de lado a lado.
  static const Duration _paceDuration = Duration(milliseconds: 2955);

  late final AnimationController _paceController;
  late final AnimationController _celebrateController;
  late final Animation<double> _celebrationScale;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _tiltBias = 0;

  @override
  void initState() {
    super.initState();
    _paceController = AnimationController(
      duration: _paceDuration,
      vsync: this,
    );
    _celebrateController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _celebrationScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]).animate(_celebrateController);

    if (!debugDisablePetMotion) {
      _paceController.repeat(reverse: true);
      _accelSub = accelerometerEventStream().listen((event) {
        if (!mounted) return;
        // Suavizado simple (low-pass) para que la mascota se desplace con la
        // inclinación en vez de temblar con cada lectura del sensor. Se
        // divide entre 4 (no entre los ~9.8 de la gravedad completa) para que
        // una inclinación cómoda de la mano ya se note, sin necesitar poner
        // el teléfono casi de lado. El signo se ajustó a ojo probando en
        // dispositivo real.
        setState(() {
          _tiltBias =
              _tiltBias + (-(event.x / 4.0).clamp(-1.0, 1.0) - _tiltBias) * 0.2;
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant PetCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.celebrationSignal != oldWidget.celebrationSignal) {
      _celebrateController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _paceController.dispose();
    _celebrateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emoji = petCatalog[widget.pet]!.emoji;
    // Mismo margen lateral que `VocabularyCard` (ver `_CardSizes.margin` en
    // home_screen.dart) para que ambas cajas se vean del mismo ancho.
    final horizontalMargin = widget.density == CardDensity.compact
        ? 12.0
        : 24.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalMargin, 16, horizontalMargin, 0),
      child: Container(
        height: _height,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _paceController,
              _celebrateController,
            ]),
            builder: (context, child) {
              final paceOffset =
                  Curves.easeInOut.transform(_paceController.value) * 2 - 1;
              // La gravedad manda: entre más inclinado esté el teléfono, más
              // se apaga el paseo, para que la mascota no "escale" contra la
              // inclinación. En una esquina (tiltBias cerca de ±1) el paseo
              // queda casi en cero y la mascota simplemente se queda ahí.
              final paceInfluence = (1 - _tiltBias.abs()).clamp(0.0, 1.0);
              final dx = (paceOffset * 0.75 * paceInfluence + _tiltBias)
                  .clamp(-1.0, 1.0);
              return Align(
                alignment: Alignment(dx, 0),
                child: Transform.scale(
                  scale: _celebrationScale.value,
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: _emojiSize),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
