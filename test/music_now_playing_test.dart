import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/music_track.dart';
import 'package:selene/music/music_now_playing.dart';

MusicTrack track({
  String id = '1',
  String name = '晴天',
  String artist = '周杰伦',
  String source = 'wy',
  String album = '叶惠美',
  String cover = 'https://example.com/cover.jpg',
}) {
  return MusicTrack(
    songId: id,
    source: source,
    name: name,
    artist: artist,
    album: album,
    cover: cover,
  );
}

void main() {
  group('MusicNowPlaying.fromPlayer', () {
    test('returns null when nothing is queued', () {
      expect(
        MusicNowPlaying.fromPlayer(
          current: null,
          queue: const [],
          queueIndex: -1,
          playing: false,
        ),
        isNull,
      );
    });

    test('maps title artist album cover and source label', () {
      final snapshot = MusicNowPlaying.fromPlayer(
        current: track(),
        queue: [track()],
        queueIndex: 0,
        playing: true,
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.id, '1');
      expect(snapshot.title, '晴天');
      expect(snapshot.artist, '周杰伦');
      expect(snapshot.album, '叶惠美');
      expect(snapshot.coverUrl, 'https://example.com/cover.jpg');
      expect(snapshot.sourceLabel, '网易云');
      expect(snapshot.displayArtist, '周杰伦');
      expect(snapshot.playing, isTrue);
    });

    test('falls back to source label when artist is empty', () {
      final snapshot = MusicNowPlaying.fromPlayer(
        current: track(artist: '', source: 'kw'),
        queue: [track(artist: '', source: 'kw')],
        queueIndex: 0,
        playing: false,
      );

      expect(snapshot!.displayArtist, '酷我');
      expect(snapshot.sourceLabel, '酷我');
    });

    test('uses a placeholder title when the song name is empty', () {
      final snapshot = MusicNowPlaying.fromPlayer(
        current: track(name: '  '),
        queue: [track(name: '  ')],
        queueIndex: 0,
        playing: false,
      );

      expect(snapshot!.title, '未知歌曲');
    });

    test('disables previous on the first track and next on the last', () {
      final songs = [track(id: 'a'), track(id: 'b'), track(id: 'c')];

      final first = MusicNowPlaying.fromPlayer(
        current: songs[0],
        queue: songs,
        queueIndex: 0,
        playing: true,
      )!;
      expect(first.canSkipPrevious, isFalse);
      expect(first.canSkipNext, isTrue);

      final middle = MusicNowPlaying.fromPlayer(
        current: songs[1],
        queue: songs,
        queueIndex: 1,
        playing: true,
      )!;
      expect(middle.canSkipPrevious, isTrue);
      expect(middle.canSkipNext, isTrue);

      final last = MusicNowPlaying.fromPlayer(
        current: songs[2],
        queue: songs,
        queueIndex: 2,
        playing: false,
      )!;
      expect(last.canSkipPrevious, isTrue);
      expect(last.canSkipNext, isFalse);
    });
  });

  group('MusicSessionPresentation.from', () {
    test('idle session exposes no controls so the card can be dismissed', () {
      final presentation = MusicSessionPresentation.from(null);
      expect(presentation.active, isFalse);
      expect(presentation.controls, isEmpty);
      expect(presentation.playing, isFalse);
      expect(presentation.processing, MusicSessionProcessing.idle);
    });

    test('playing session exposes pause stop and available skips', () {
      final presentation = MusicSessionPresentation.from(
        MusicNowPlaying.fromPlayer(
          current: track(),
          queue: [track(), track(id: '2')],
          queueIndex: 0,
          playing: true,
        ),
      );

      expect(presentation.active, isTrue);
      expect(presentation.playing, isTrue);
      expect(presentation.processing, MusicSessionProcessing.ready);
      expect(presentation.controls, [
        MusicSessionControl.pause,
        MusicSessionControl.next,
        MusicSessionControl.stop,
      ]);
    });

    test('paused session keeps the card with play and previous when available', () {
      final presentation = MusicSessionPresentation.from(
        MusicNowPlaying.fromPlayer(
          current: track(id: '2'),
          queue: [track(), track(id: '2')],
          queueIndex: 1,
          playing: false,
          loading: true,
        ),
      );

      expect(presentation.active, isTrue);
      expect(presentation.playing, isFalse);
      expect(presentation.processing, MusicSessionProcessing.loading);
      expect(presentation.controls, [
        MusicSessionControl.previous,
        MusicSessionControl.play,
        MusicSessionControl.stop,
      ]);
    });
  });
}
