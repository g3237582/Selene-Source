import 'package:flutter/material.dart';

import '../models/music_track.dart';
import '../services/music_player_service.dart';
import '../utils/font_utils.dart';
import '../widgets/authenticated_image.dart';
import '../widgets/music_lyrics_view.dart';
import '../widgets/music_progress_bar.dart';

class MusicPlayerPageKeys {
  static const cover = Key('music-player-cover');
  static const title = Key('music-player-title');
  static const artist = Key('music-player-artist');
  static const lyrics = Key('music-player-lyrics');
  static const progress = Key('music-player-progress');
  static const controls = Key('music-player-controls');
}

class MusicPlayerScreen extends StatelessWidget {
  const MusicPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = MusicPlayerService.instance;
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final track = player.current;
        return Scaffold(
          appBar: AppBar(
            title: Text(track?.name ?? '正在播放', style: FontUtils.poppins(fontSize: 16)),
            actions: [
              if (track != null)
                IconButton(
                  tooltip: '停止播放',
                  onPressed: player.stopAndClear,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
            ],
          ),
          body: track == null
              ? const Center(child: Text('还没有播放歌曲'))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: MusicPlayerPageContent(
                    track: track,
                    lyric: player.lyric,
                    positionStream: player.player.stream.position,
                    initialPosition: player.player.state.position,
                    progress: MusicProgressBar(
                      player: player.player,
                      loading: player.loading,
                    ),
                    playing: player.playing,
                    loading: player.loading,
                    errorMessage: player.errorMessage,
                    onPrevious: player.playPrevious,
                    onTogglePlay: player.togglePlay,
                    onNext: player.playNext,
                  ),
                ),
        );
      },
    );
  }
}

/// Full-player body: cover → title/artist → lyrics → progress → controls.
class MusicPlayerPageContent extends StatelessWidget {
  const MusicPlayerPageContent({
    super.key,
    required this.track,
    required this.lyric,
    required this.positionStream,
    this.initialPosition = Duration.zero,
    required this.progress,
    required this.playing,
    required this.loading,
    required this.errorMessage,
    required this.onPrevious,
    required this.onTogglePlay,
    required this.onNext,
  });

  final MusicTrack track;
  final String lyric;
  final Stream<Duration> positionStream;
  final Duration initialPosition;
  final Widget progress;
  final bool playing;
  final bool loading;
  final String errorMessage;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KeyedSubtree(
          key: MusicPlayerPageKeys.cover,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 240,
              height: 240,
              child: track.cover.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFF2c3e50),
                      child: Icon(Icons.music_note, size: 72, color: Colors.white70),
                    )
                  : AuthenticatedImage(url: track.cover),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          track.name,
          key: MusicPlayerPageKeys.title,
          textAlign: TextAlign.center,
          style: FontUtils.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          track.artist,
          key: MusicPlayerPageKeys.artist,
          style: FontUtils.poppins(color: const Color(0xFF7f8c8d)),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: KeyedSubtree(
            key: MusicPlayerPageKeys.lyrics,
            child: MusicLyricsView(
              key: ValueKey(track.songId),
              lyric: lyric,
              positionStream: positionStream,
              initialPosition: initialPosition,
            ),
          ),
        ),
        if (errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorMessage,
              style: FontUtils.poppins(color: const Color(0xFFe74c3c)),
            ),
          ),
        const SizedBox(height: 8),
        KeyedSubtree(
          key: MusicPlayerPageKeys.progress,
          child: progress,
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: MusicPlayerPageKeys.controls,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                onPressed: onPrevious,
                icon: const Icon(Icons.skip_previous),
              ),
              const SizedBox(width: 12),
              IconButton(
                iconSize: 64,
                onPressed: loading ? null : onTogglePlay,
                icon: Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: const Color(0xFF27ae60),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                iconSize: 36,
                onPressed: onNext,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
