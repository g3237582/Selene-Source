import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/music_track.dart';
import 'package:selene/music/music_media_session_controller.dart';
import 'package:selene/music/music_now_playing.dart';

class _RecordingPublisher implements MusicSessionPublisher {
  MusicNowPlaying? last;
  int publishCount = 0;
  int clearCount = 0;

  @override
  Future<void> publish(MusicNowPlaying nowPlaying) async {
    last = nowPlaying;
    publishCount++;
  }

  @override
  Future<void> clear() async {
    last = null;
    clearCount++;
  }
}

class _RecordingCommands implements MusicPlaybackCommands {
  final calls = <String>[];
  Duration? seekTo;

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> playNext() async => calls.add('next');

  @override
  Future<void> playPrevious() async => calls.add('previous');

  @override
  Future<void> stopAndClear() async => calls.add('stop');

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek');
    seekTo = position;
  }
}

void main() {
  const song = MusicTrack(
    songId: '9',
    source: 'tx',
    name: '七里香',
    artist: '周杰伦',
  );

  MusicNowPlaying snapshot({bool playing = true}) {
    return MusicNowPlaying.fromPlayer(
      current: song,
      queue: [song],
      queueIndex: 0,
      playing: playing,
    )!;
  }

  test('sync publishes an active card and clear removes it', () async {
    final publisher = _RecordingPublisher();
    final controller = MusicMediaSessionController(
      commands: _RecordingCommands(),
      publisher: publisher,
    );

    await controller.sync(snapshot());
    expect(publisher.publishCount, 1);
    expect(publisher.last?.title, '七里香');
    expect(publisher.last?.sourceLabel, 'QQ');

    await controller.sync(null);
    expect(publisher.clearCount, 1);
    expect(publisher.last, isNull);
  });

  test('lock-screen commands drive the same playback service hooks', () async {
    final commands = _RecordingCommands();
    final controller = MusicMediaSessionController(
      commands: commands,
      publisher: _RecordingPublisher(),
    );

    await controller.play();
    await controller.pause();
    await controller.skipToNext();
    await controller.skipToPrevious();
    await controller.seek(const Duration(seconds: 12));
    await controller.stop();

    expect(commands.calls, ['play', 'pause', 'next', 'previous', 'seek', 'stop']);
    expect(commands.seekTo, const Duration(seconds: 12));
  });
}
