import 'package:flutter/material.dart';

import '../models/music_track.dart';
import '../screens/music_player_screen.dart';
import '../services/music_player_service.dart';
import '../utils/font_utils.dart';
import '../utils/paged_list.dart';
import 'music_track_tile.dart';
import 'paged_catalog_scroll.dart';

class MusicSearchField extends StatelessWidget {
  final TextEditingController controller;
  final Color muted;
  final Color textColor;
  final Color fillColor;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  const MusicSearchField({
    super.key,
    required this.controller,
    required this.muted,
    required this.textColor,
    required this.fillColor,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmitted(),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: '搜索歌曲、歌手',
          hintStyle: FontUtils.poppins(color: muted, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: muted),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward, color: Color(0xFF27ae60)),
            onPressed: onSubmitted,
          ),
          filled: true,
          fillColor: fillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        style: FontUtils.poppins(color: textColor, fontSize: 14),
      ),
    );
  }
}

class MusicSearchList extends StatelessWidget {
  final List<MusicTrack> items;
  final bool hasMore;
  final ValueNotifier<bool> loadingMore;
  final bool searching;
  final String? error;
  final String sourceKey;
  final Color muted;
  final VoidCallback onLoadMore;

  const MusicSearchList({
    super.key,
    required this.items,
    required this.hasMore,
    required this.loadingMore,
    required this.searching,
    required this.error,
    required this.sourceKey,
    required this.muted,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (shouldReplaceCatalogWithLoader(
      loading: searching,
      itemCount: items.length,
    )) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && items.isEmpty) {
      return Center(child: Text(error!, style: FontUtils.poppins(color: muted)));
    }
    final player = MusicPlayerService.instance;
    return PagedCatalogScroll(
      key: ValueKey(sourceKey),
      itemCount: items.length,
      hasMore: hasMore,
      loadingMoreListenable: loadingMore,
      onLoadMore: onLoadMore,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      empty: Center(
        child: Text('未找到相关歌曲', style: FontUtils.poppins(color: muted)),
      ),
      itemBuilder: (context, index) {
        final track = items[index];
        return ListenableBuilder(
          key: ValueKey('${track.source}-${track.songId}'),
          listenable: player,
          builder: (context, _) {
            final playing = player.current?.songId == track.songId;
            return MusicTrackTile(
              track: track,
              playing: playing,
              paused: playing && !player.playing,
              onTap: () => player.playTrack(track, playlist: items),
              onOpenPlayer: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                );
              },
            );
          },
        );
      },
    );
  }
}
