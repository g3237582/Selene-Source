import 'package:flutter/material.dart';

import '../services/music_player_service.dart';
import '../utils/font_utils.dart';
import '../widgets/authenticated_image.dart';
import '../widgets/music_lyrics_view.dart';
import '../widgets/music_progress_bar.dart';

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
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 240,
                          height: 240,
                          child: track.cover.isEmpty
                              ? const ColoredBox(
                                  color: Color(0xFF2c3e50),
                                  child: Icon(Icons.music_note,
                                      size: 72, color: Colors.white70),
                                )
                              : AuthenticatedImage(url: track.cover),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        track.name,
                        textAlign: TextAlign.center,
                        style: FontUtils.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track.artist,
                        style: FontUtils.poppins(color: const Color(0xFF7f8c8d)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 36,
                            onPressed: player.playPrevious,
                            icon: const Icon(Icons.skip_previous),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            iconSize: 64,
                            onPressed: player.loading ? null : player.togglePlay,
                            icon: Icon(
                              player.playing
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: const Color(0xFF27ae60),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            iconSize: 36,
                            onPressed: player.playNext,
                            icon: const Icon(Icons.skip_next),
                          ),
                        ],
                      ),
                      if (player.loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(),
                        ),
                      if (player.errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            player.errorMessage,
                            style: FontUtils.poppins(color: const Color(0xFFe74c3c)),
                          ),
                        ),
                      const SizedBox(height: 8),
                      MusicProgressBar(player: player.player),
                      const SizedBox(height: 12),
                      Expanded(
                        child: MusicLyricsView(
                          key: ValueKey(player.current?.songId ?? ''),
                          lyric: player.lyric,
                          positionStream: player.player.stream.position,
                          initialPosition: player.player.state.position,
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
