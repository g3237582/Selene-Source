import 'music_now_playing.dart';

/// Playback actions the lock-screen / notification card must drive.
abstract class MusicPlaybackCommands {
  Future<void> play();
  Future<void> pause();
  Future<void> playNext();
  Future<void> playPrevious();
  Future<void> stopAndClear();
  Future<void> seek(Duration position);
}

/// Platform publisher (audio_service MediaSession, etc.).
abstract class MusicSessionPublisher {
  Future<void> publish(MusicNowPlaying nowPlaying);
  Future<void> clear();
}

/// Forwards remote commands to [MusicPlayerService] and publishes card state.
class MusicMediaSessionController {
  MusicMediaSessionController({
    required this.commands,
    required this.publisher,
  });

  /// Lock-screen progress stays alive without flooding MediaSession.
  static const positionTickInterval = Duration(seconds: 1);

  final MusicPlaybackCommands commands;
  final MusicSessionPublisher publisher;
  DateTime? lastPublishAt;

  Future<void> sync(MusicNowPlaying? snapshot, {DateTime? now}) {
    lastPublishAt = now ?? DateTime.now();
    if (snapshot == null) return publisher.clear();
    return publisher.publish(snapshot);
  }

  /// Republish PlaybackState on position ticks while playing so OEM
  /// MediaStyle cards keep the session visible and the seek bar moves.
  Future<void> syncPositionTick(MusicNowPlaying? snapshot, {DateTime? now}) {
    now ??= DateTime.now();
    if (snapshot == null || !snapshot.playing) return Future.value();
    final last = lastPublishAt;
    if (last != null && now.difference(last) < positionTickInterval) {
      return Future.value();
    }
    return sync(snapshot, now: now);
  }

  Future<void> play() => commands.play();

  Future<void> pause() => commands.pause();

  Future<void> skipToNext() => commands.playNext();

  Future<void> skipToPrevious() => commands.playPrevious();

  Future<void> stop() => commands.stopAndClear();

  Future<void> seek(Duration position) => commands.seek(position);
}
