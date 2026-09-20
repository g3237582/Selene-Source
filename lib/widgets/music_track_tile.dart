import 'package:flutter/material.dart';

import '../models/music_track.dart';
import '../utils/font_utils.dart';
import 'authenticated_image.dart';

class MusicTrackTile extends StatelessWidget {
  final MusicTrack track;
  final bool playing;
  final bool paused;
  final int? index;
  final VoidCallback onTap;
  final VoidCallback? onOpenPlayer;

  const MusicTrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.playing = false,
    this.paused = false,
    this.index,
    this.onOpenPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF2c3e50);
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index != null)
            SizedBox(
              width: 28,
              child: Text(
                '${index! + 1}',
                textAlign: TextAlign.center,
                style: FontUtils.poppins(
                  fontSize: 13,
                  color: playing ? const Color(0xFF27ae60) : const Color(0xFF7f8c8d),
                ),
              ),
            ),
          SizedBox(
            width: 48,
            height: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: track.cover.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFF2c3e50),
                      child: Icon(Icons.music_note, color: Colors.white70),
                    )
                  : AuthenticatedImage(url: track.cover),
            ),
          ),
        ],
      ),
      title: Text(
        track.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FontUtils.poppins(
          fontWeight: playing ? FontWeight.w600 : FontWeight.w400,
          color: playing ? const Color(0xFF27ae60) : textColor,
        ),
      ),
      subtitle: Text(
        [
          track.artist,
          track.album,
          musicSourceLabels[track.source] ?? track.source,
        ].where((item) => item.isNotEmpty).join(' · '),
        maxLines: 1,
      ),
      trailing: Icon(
        playing && !paused ? Icons.pause_circle : Icons.play_circle,
        color: const Color(0xFF27ae60),
      ),
      onTap: onTap,
      onLongPress: onOpenPlayer,
    );
  }
}
