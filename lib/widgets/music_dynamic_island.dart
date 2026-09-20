double musicIslandProgressFraction({
  required Duration position,
  required Duration duration,
}) {
  if (duration <= Duration.zero) return 0.0;
  final value = position.inMilliseconds / duration.inMilliseconds;
  if (value.isNaN) return 0.0;
  return value.clamp(0.0, 1.0);
}

bool shouldShowMusicIsland({
  required bool hasCurrentTrack,
  required bool isOnFullPlayerRoute,
}) {
  return hasCurrentTrack && !isOnFullPlayerRoute;
}
