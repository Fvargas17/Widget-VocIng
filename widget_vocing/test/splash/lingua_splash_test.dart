import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:widget_vocing/splash/lingua_splash.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

void main() {
  test('con carga inmediata dura entre 3.5 y 4.5 s', () {
    final end = SplashTimeline.endTime(SplashTimeline.decideHillIndex(0));
    expect(end, inInclusiveRange(3.5, 4.5));
  });

  test('si la carga tarda, la colina aparece al menos 2 saltos después', () {
    const t = 2.6;
    final hill = SplashTimeline.decideHillIndex(t);
    expect(SplashTimeline.landingTime(hill - 1), greaterThan(t + 2 * SplashTimeline.hop));
  });

  testWidgets('pinta todas las fases y llama onFinished una sola vez', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_host(LinguaSplash(onFinished: () => calls++)));
    for (var i = 0; i < 43; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // ~4.2 s
    }
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sigue corriendo mientras la carga no termina', (tester) async {
    final loading = Completer<void>();
    var done = false;
    await tester.pumpWidget(_host(LinguaSplash(loading: loading.future, onFinished: () => done = true)));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // 6 s
    }
    expect(done, isFalse);
    loading.complete();
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(done, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con "reducir movimiento" muestra la pose final y termina pronto', (tester) async {
    var done = false;
    await tester.pumpWidget(_host(LinguaSplash(onFinished: () => done = true), reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(done, isTrue);
  });
}
