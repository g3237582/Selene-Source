/// Display and seek-settling math for the player progress bar.
class PlayerProgress {
  static const Duration seekSettleEpsilon = Duration(milliseconds: 450);
  static const Duration seekSettleTimeout = Duration(milliseconds: 1800);

  static double playValue({
    required Duration duration,
    required Duration position,
    required bool live,
    required bool dragging,
    required double dragValue,
    Duration? pendingSeek,
  }) {
    if (duration.inMilliseconds <= 0) {
      return 0.0;
    }
    if (live) {
      return 1.0;
    }
    if (dragging) {
      return dragValue.clamp(0.0, 1.0);
    }
    final shown = pendingSeek ?? position;
    return (shown.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  static double bufferValue({
    required Duration duration,
    required Duration buffered,
  }) {
    if (duration.inMilliseconds <= 0) {
      return 0.0;
    }
    return (buffered.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  static bool seekSettled({
    required Duration actual,
    required Duration target,
    required DateTime startedAt,
    DateTime? now,
    Duration epsilon = seekSettleEpsilon,
    Duration timeout = seekSettleTimeout,
  }) {
    final clock = now ?? DateTime.now();
    if (clock.difference(startedAt) >= timeout) {
      return true;
    }
    return (actual.inMilliseconds - target.inMilliseconds).abs() <=
        epsilon.inMilliseconds;
  }
}
