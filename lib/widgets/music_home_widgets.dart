import 'package:flutter/material.dart';

import '../models/music_discovery.dart';
import '../utils/font_utils.dart';
import 'authenticated_image.dart';

class MusicHomeTabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onChanged;

  const MusicHomeTabBar({
    super.key,
    required this.tab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFb0b0b0)
        : const Color(0xFF7f8c8d);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _chip('排行榜', 0, muted),
          const SizedBox(width: 8),
          _chip('推荐歌单', 1, muted),
        ],
      ),
    );
  }

  Widget _chip(String label, int value, Color muted) {
    final selected = tab == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(value),
      selectedColor: const Color(0xFF27ae60),
      labelStyle: FontUtils.poppins(color: selected ? Colors.white : muted),
    );
  }
}

class MusicBoardList extends StatelessWidget {
  final List<MusicBoard> boards;
  final ValueChanged<MusicBoard> onTap;

  const MusicBoardList({
    super.key,
    required this.boards,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (boards.isEmpty) {
      return Center(
        child: Text('当前音源暂无排行榜数据', style: FontUtils.poppins(color: const Color(0xFF7f8c8d))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: boards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final board = boards[index];
        return Material(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1e1e1e)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onTap(board),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF27ae60).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (index + 1).toString().padLeft(2, '0'),
                      style: FontUtils.poppins(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF27ae60),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          board.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FontUtils.poppins(fontWeight: FontWeight.w600),
                        ),
                        if (board.updateFrequency.isNotEmpty)
                          Text(
                            board.updateFrequency,
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
                  const Icon(Icons.chevron_right, color: Color(0xFF7f8c8d)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MusicPlaylistGrid extends StatelessWidget {
  final List<MusicPlaylist> items;
  final ValueChanged<MusicPlaylist> onTap;

  const MusicPlaylistGrid({
    super.key,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text('当前音源暂无推荐歌单数据', style: FontUtils.poppins(color: const Color(0xFF7f8c8d))),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => onTap(item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.cover.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFF2c3e50),
                          child: Center(
                            child: Icon(Icons.queue_music, color: Colors.white70),
                          ),
                        )
                      : AuthenticatedImage(url: item.cover),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FontUtils.poppins(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                [
                  if (item.author.isNotEmpty) item.author,
                  if (item.songCount > 0) '${item.songCount} 首',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FontUtils.poppins(fontSize: 11, color: const Color(0xFF7f8c8d)),
              ),
            ],
          ),
        );
      },
    );
  }
}
