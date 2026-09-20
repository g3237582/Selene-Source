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

  final MusicPlaybackCommands commands;
  final MusicSessionPublisher publisher;

  Future<void> sync(MusicNowPlaying? snapshot) {
    if (snapshot == null) return publisher.clear();
    return publisher.publish(snapshot);
  }

  Future<void> play() => commands.play();

  Future<void> pause() => commands.pause();

  Future<void> skipToNext() => commands.playNext();

  Future<void> skipToPrevious() => commands.playPrevious();

  Future<void> stop() => commands.stopAndClear();

  Future<void> seek(Duration position) => commands.seek(position);
}
