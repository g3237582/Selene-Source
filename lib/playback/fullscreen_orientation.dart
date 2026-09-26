import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Landscape is the historical fullscreen default. Portrait is an explicit
/// alternate that still fills the screen with [BoxFit.contain].
enum FullscreenOrientationMode { landscape, portrait }

/// Chooses fullscreen orientation from an optional user choice and the
/// video's display size.
///
/// [videoWidth] and [videoHeight] are the display dimensions (media_kit
/// already swaps them when the frame is rotated 90 or 270 degrees).
/// Unknown, empty, square, and horizontal frames stay landscape.
class FullscreenOrientation {
  static FullscreenOrientationMode decide({
    FullscreenOrientationMode? preference,
    int? videoWidth,
    int? videoHeight,
  }) {
    if (preference != null) {
      return preference;
    }
    final width = videoWidth;
    final height = videoHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return FullscreenOrientationMode.landscape;
    }
    if (height > width) {
      return FullscreenOrientationMode.portrait;
    }
    return FullscreenOrientationMode.landscape;
  }

  static FullscreenOrientationMode toggle(FullscreenOrientationMode current) {
    return current == FullscreenOrientationMode.landscape
        ? FullscreenOrientationMode.portrait
        : FullscreenOrientationMode.landscape;
  }

  static List<DeviceOrientation> deviceOrientations(
    FullscreenOrientationMode mode,
  ) {
    switch (mode) {
      case FullscreenOrientationMode.portrait:
        return const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ];
      case FullscreenOrientationMode.landscape:
        return const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
    }
  }
}

/// Fullscreen orientation for one playback session.
///
/// Auto-selection runs on enter and when the frame size arrives later.
/// A manual toggle is kept until fullscreen exits, then the next enter
/// is auto again so horizontal video stays landscape by default.
class FullscreenOrientationSession
    extends ValueNotifier<FullscreenOrientationMode> {
  FullscreenOrientationSession() : super(FullscreenOrientationMode.landscape);

  FullscreenOrientationMode? _manual;

  bool get hasManualChoice => _manual != null;

  void onEnter({int? videoWidth, int? videoHeight}) {
    value = FullscreenOrientation.decide(
      preference: _manual,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
    );
  }

  /// Updates auto fullscreen when a frame size becomes known.
  /// Returns whether the active orientation changed.
  bool adoptFrame({int? videoWidth, int? videoHeight}) {
    if (_manual != null) {
      return false;
    }
    final next = FullscreenOrientation.decide(
      videoWidth: videoWidth,
      videoHeight: videoHeight,
    );
    if (next == value) {
      return false;
    }
    value = next;
    return true;
  }

  FullscreenOrientationMode toggle() {
    final next = FullscreenOrientation.toggle(value);
    _manual = next;
    value = next;
    return next;
  }

  void onExit() {
    _manual = null;
    value = FullscreenOrientationMode.landscape;
  }
}

/// Status-bar / home-indicator inset that still works in immersive mode.
///
/// `SystemUiMode.immersiveSticky` zeros [MediaQueryData.padding] while the
/// cutout remains in [MediaQueryData.viewPadding].
EdgeInsets fullscreenControlSafeInset({
  required EdgeInsets padding,
  required EdgeInsets viewPadding,
}) {
  return EdgeInsets.fromLTRB(
    math.max(padding.left, viewPadding.left),
    math.max(padding.top, viewPadding.top),
    math.max(padding.right, viewPadding.right),
    math.max(padding.bottom, viewPadding.bottom),
  );
}

bool fullscreenOrientationLockSupported() {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Applies the same immersive chrome media_kit uses for mobile fullscreen,
/// with an explicit orientation. Desktop and web keep media_kit's native
/// fullscreen callbacks so those paths stay unchanged.
class FullscreenChrome {
  static Future<void> enter(FullscreenOrientationMode mode) async {
    try {
      if (fullscreenOrientationLockSupported()) {
        await Future.wait(
          [
            SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.immersiveSticky,
              overlays: [],
            ),
            SystemChrome.setPreferredOrientations(
              FullscreenOrientation.deviceOrientations(mode),
            ),
          ],
        );
        return;
      }
      await defaultEnterNativeFullscreen();
    } catch (error, stack) {
      debugPrint('FullscreenChrome.enter failed: $error');
      debugPrint('$stack');
    }
  }

  static Future<void> apply(FullscreenOrientationMode mode) async {
    try {
      if (!fullscreenOrientationLockSupported()) {
        return;
      }
      await SystemChrome.setPreferredOrientations(
        FullscreenOrientation.deviceOrientations(mode),
      );
    } catch (error, stack) {
      debugPrint('FullscreenChrome.apply failed: $error');
      debugPrint('$stack');
    }
  }

  /// Matches [defaultExitNativeFullscreen]: manual system overlays and an
  /// empty preferred-orientation list.
  static Future<void> exit() => defaultExitNativeFullscreen();
}
