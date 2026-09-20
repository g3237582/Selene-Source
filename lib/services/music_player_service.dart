import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../models/music_track.dart';
import 'music_service.dart';

class MusicPlayerService extends ChangeNotifier {
  MusicPlayerService._() {
    player.stream.playing.listen((value) {
      playing = value;
      notifyListeners();
    });
    player.stream.completed.listen((completed) {
      if (completed) {
        playNext();
      }
    });
  }

  /// Created on first access so media_kit can be initialized in `main()`.
  static MusicPlayerService? _instance;
  static MusicPlayerService get instance =>
      _instance ??= MusicPlayerService._();

  /// Hook for lock-screen / notification permission when a session starts.
  static Future<void> Function()? onActiveSession;

  final Player player = Player();

  MusicTrack? current;
  List<MusicTrack> queue = const [];
  int queueIndex = -1;
  bool playing = false;
  bool loading = false;
  String lyric = '';
  String errorMessage = '';

  Future<void> playTrack(MusicTrack track, {List<MusicTrack>? playlist}) async {
    if (playlist != null) {
      queue = playlist;
      queueIndex = playlist.indexWhere((item) => item.songId == track.songId);
      if (queueIndex < 0) {
        queue = [track, ...playlist];
        queueIndex = 0;
      }
    } else if (queue.isEmpty) {
      queue = [track];
      queueIndex = 0;
    } else {
      final existing = queue.indexWhere((item) => item.songId == track.songId);
      queueIndex = existing >= 0 ? existing : queueIndex;
    }

    loading = true;
    errorMessage = '';
    current = track;
    notifyListeners();
    await onActiveSession?.call();

    try {
      final result = await MusicService.play(track);
      final url = await MusicService.resolveMediaUrl(result.streamUrl);
      final headers = await MusicService.cookieHeaders();
      lyric = result.lyric;
      current = result.song;
      await player.open(
        Media(url, httpHeaders: headers),
        play: true,
      );
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> playPlaylist(List<MusicTrack> tracks, {int index = 0}) async {
    if (tracks.isEmpty) return;
    final start = index < 0 || index >= tracks.length ? 0 : index;
    await playTrack(tracks[start], playlist: tracks);
  }

  Future<void> play() async {
    if (current == null) return;
    await player.play();
  }

  Future<void> pause() async {
    await player.pause();
  }

  Future<void> togglePlay() async {
    if (current == null) return;
    await player.playOrPause();
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  Future<void> stopAndClear() async {
    try {
      await player.stop();
    } catch (error) {
      debugPrint('MusicPlayerService.stopAndClear: $error');
    }
    current = null;
    queue = const [];
    queueIndex = -1;
    playing = false;
    loading = false;
    lyric = '';
    errorMessage = '';
    notifyListeners();
  }

  Future<void> playNext() async {
    if (queue.isEmpty) return;
    final nextIndex = queueIndex + 1;
    if (nextIndex >= queue.length) return;
    queueIndex = nextIndex;
    await playTrack(queue[nextIndex]);
  }

  Future<void> playPrevious() async {
    if (queue.isEmpty) return;
    final prevIndex = queueIndex - 1;
    if (prevIndex < 0) return;
    queueIndex = prevIndex;
    await playTrack(queue[prevIndex]);
  }
}
