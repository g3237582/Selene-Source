import 'package:flutter/material.dart';

import '../screens/music_player_screen.dart';
import '../services/music_player_service.dart';
import '../utils/font_utils.dart';
import 'authenticated_image.dart';

class MusicMiniPlayer extends StatelessWidget {
  const MusicMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = MusicPlayerService.instance;
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final track = player.current;
        if (track == null) {
          return const SizedBox.shrink();
        }
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
              );
            },
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1e1e1e)
                    : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: track.cover.isEmpty
                          ? const ColoredBox(
                              color: Color(0xFF2c3e50),
                              child: Icon(Icons.music_note, color: Colors.white70),
                            )
                          : AuthenticatedImage(url: track.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FontUtils.poppins(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FontUtils.poppins(
                            fontSize: 12,
                            color: const Color(0xFF7f8c8d),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: player.loading ? null : player.togglePlay,
                    icon: Icon(
                      player.playing ? Icons.pause : Icons.play_arrow,
                      color: const Color(0xFF27ae60),
                    ),
                  ),
                  IconButton(
                    onPressed: player.playNext,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
