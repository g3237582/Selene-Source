import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/playback/fullscreen_orientation.dart';

void main() {
  group('FullscreenOrientation.decide', () {
    test('keeps landscape for horizontal video', () {
      expect(
        FullscreenOrientation.decide(videoWidth: 1920, videoHeight: 1080),
        FullscreenOrientationMode.landscape,
      );
    });

    test('picks portrait when the frame is taller than wide', () {
      expect(
        FullscreenOrientation.decide(videoWidth: 1080, videoHeight: 1920),
        FullscreenOrientationMode.portrait,
      );
    });

    test('keeps landscape for square, unknown, and empty frames', () {
      expect(
        FullscreenOrientation.decide(videoWidth: 1000, videoHeight: 1000),
        FullscreenOrientationMode.landscape,
      );
      expect(
        FullscreenOrientation.decide(),
        FullscreenOrientationMode.landscape,
      );
      expect(
        FullscreenOrientation.decide(videoWidth: 0, videoHeight: 1920),
        FullscreenOrientationMode.landscape,
      );
      expect(
        FullscreenOrientation.decide(videoWidth: -1, videoHeight: 100),
        FullscreenOrientationMode.landscape,
      );
    });

    test('manual preference overrides aspect ratio', () {
      expect(
        FullscreenOrientation.decide(
          preference: FullscreenOrientationMode.portrait,
          videoWidth: 1920,
          videoHeight: 1080,
        ),
        FullscreenOrientationMode.portrait,
      );
      expect(
        FullscreenOrientation.decide(
          preference: FullscreenOrientationMode.landscape,
          videoWidth: 1080,
          videoHeight: 1920,
        ),
        FullscreenOrientationMode.landscape,
      );
    });
  });

  group('FullscreenOrientationSession', () {
    test('auto-enters portrait for a vertical frame', () {
      final session = FullscreenOrientationSession();
      session.onEnter(videoWidth: 720, videoHeight: 1280);
      expect(session.value, FullscreenOrientationMode.portrait);
      expect(session.hasManualChoice, isFalse);
    });

    test('toggle is remembered until fullscreen exits', () {
      final session = FullscreenOrientationSession();
      session.onEnter(videoWidth: 1920, videoHeight: 1080);
      expect(session.toggle(), FullscreenOrientationMode.portrait);
      expect(session.hasManualChoice, isTrue);

      session.onEnter(videoWidth: 1920, videoHeight: 1080);
      expect(session.value, FullscreenOrientationMode.portrait);

      var adopted = session.adoptFrame(videoWidth: 1920, videoHeight: 1080);
      expect(adopted, isFalse);
      expect(session.value, FullscreenOrientationMode.portrait);

      session.onExit();
      expect(session.value, FullscreenOrientationMode.landscape);
      expect(session.hasManualChoice, isFalse);

      session.onEnter(videoWidth: 1920, videoHeight: 1080);
      expect(session.value, FullscreenOrientationMode.landscape);
    });

    test('adopts portrait when the frame size arrives after enter', () {
      final session = FullscreenOrientationSession();
      session.onEnter();
      expect(session.value, FullscreenOrientationMode.landscape);

      final adopted = session.adoptFrame(videoWidth: 1080, videoHeight: 1920);
      expect(adopted, isTrue);
      expect(session.value, FullscreenOrientationMode.portrait);

      expect(
        session.adoptFrame(videoWidth: 1080, videoHeight: 1920),
        isFalse,
      );
    });

    test('toggle twice returns to the previous orientation', () {
      final session = FullscreenOrientationSession();
      session.onEnter(videoWidth: 1080, videoHeight: 1920);
      session.toggle();
      expect(session.value, FullscreenOrientationMode.landscape);
      session.toggle();
      expect(session.value, FullscreenOrientationMode.portrait);
    });
  });

  test('device orientations match the fullscreen mode', () {
    expect(
      FullscreenOrientation.deviceOrientations(
        FullscreenOrientationMode.landscape,
      ),
      [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
    expect(
      FullscreenOrientation.deviceOrientations(
        FullscreenOrientationMode.portrait,
      ),
      [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );
  });

  test('immersive fullscreen controls keep the larger safe inset', () {
    final inset = fullscreenControlSafeInset(
      padding: const EdgeInsets.only(left: 8),
      viewPadding: const EdgeInsets.only(top: 47, bottom: 34, right: 12),
    );
    expect(inset.top, 47);
    expect(inset.bottom, 34);
    expect(inset.left, 8);
    expect(inset.right, 12);
  });
}
