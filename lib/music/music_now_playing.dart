import '../models/music_track.dart';

/// Snapshot of the lock-screen / media-notification card.
class MusicNowPlaying {
  const MusicNowPlaying({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.sourceLabel,
    required this.coverUrl,
    required this.playing,
    required this.canSkipNext,
    required this.canSkipPrevious,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.loading = false,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String sourceLabel;
  final String coverUrl;
  final bool playing;
  final bool canSkipNext;
  final bool canSkipPrevious;
  final Duration position;
  final Duration duration;
  final bool loading;

  /// Artist when present, otherwise the Chinese source label.
  String get displayArtist {
    final trimmed = artist.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return sourceLabel;
  }

  static MusicNowPlaying? fromPlayer({
    required MusicTrack? current,
    required List<MusicTrack> queue,
    required int queueIndex,
    required bool playing,
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
    bool loading = false,
  }) {
    if (current == null) return null;
    final name = current.name.trim();
    return MusicNowPlaying(
      id: current.songId,
      title: name.isNotEmpty ? name : '未知歌曲',
      artist: current.artist,
      album: current.album,
      sourceLabel: musicSourceLabels[current.source] ?? current.source,
      coverUrl: current.cover,
      playing: playing,
      canSkipNext: canSkipNextInQueue(queue, queueIndex),
      canSkipPrevious: canSkipPreviousInQueue(queue, queueIndex),
      position: position,
      duration: duration,
      loading: loading,
    );
  }

  static bool canSkipNextInQueue(List<MusicTrack> queue, int queueIndex) {
    return queue.isNotEmpty && queueIndex >= 0 && queueIndex < queue.length - 1;
  }

  static bool canSkipPreviousInQueue(List<MusicTrack> queue, int queueIndex) {
    return queue.isNotEmpty && queueIndex > 0;
  }
}

enum MusicSessionControl { previous, play, pause, next, stop }

enum MusicSessionProcessing { idle, loading, ready }

/// Notification / lock-screen controls derived from [MusicNowPlaying].
class MusicSessionPresentation {
  const MusicSessionPresentation({
    required this.active,
    required this.playing,
    required this.processing,
    required this.controls,
  });

  final bool active;
  final bool playing;
  final MusicSessionProcessing processing;
  final List<MusicSessionControl> controls;

  static MusicSessionPresentation from(MusicNowPlaying? nowPlaying) {
    if (nowPlaying == null) {
      return const MusicSessionPresentation(
        active: false,
        playing: false,
        processing: MusicSessionProcessing.idle,
        controls: [],
      );
    }

    return MusicSessionPresentation(
      active: true,
      playing: nowPlaying.playing,
      processing: nowPlaying.loading
          ? MusicSessionProcessing.loading
          : MusicSessionProcessing.ready,
      controls: [
        if (nowPlaying.canSkipPrevious) MusicSessionControl.previous,
        nowPlaying.playing
            ? MusicSessionControl.pause
            : MusicSessionControl.play,
        if (nowPlaying.canSkipNext) MusicSessionControl.next,
        MusicSessionControl.stop,
      ],
    );
  }
}
