import 'package:flutter/material.dart';

import '../models/music_discovery.dart';
import '../utils/font_utils.dart';
import 'authenticated_image.dart';
import 'paged_catalog_scroll.dart';

class MusicSongListFilters extends StatelessWidget {
  final String sortId;
  final String tagId;
  final List<MusicTag> tags;
  final bool showTags;
  final Color textColor;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onTagChanged;

  const MusicSongListFilters({
    super.key,
    required this.sortId,
    required this.tagId,
    required this.tags,
    required this.showTags,
    required this.textColor,
    required this.onSortChanged,
    required this.onTagChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final item in const [
                ('hot', '最热'),
                ('new', '最新'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.$2),
                    selected: sortId == item.$1,
                    onSelected: (_) => onSortChanged(item.$1),
                    selectedColor: const Color(0xFF27ae60),
                    labelStyle: FontUtils.poppins(
                      fontSize: 12,
                      color: sortId == item.$1 ? Colors.white : textColor,
                    ),
                  ),
                ),
            ],
          ),
          if (showTags && tags.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tags.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ChoiceChip(
                      label: const Text('全部'),
                      selected: tagId.isEmpty,
                      onSelected: (_) => onTagChanged(''),
                      selectedColor: const Color(0xFF27ae60),
                      labelStyle: FontUtils.poppins(
                        fontSize: 12,
                        color: tagId.isEmpty ? Colors.white : textColor,
                      ),
                    );
                  }
                  final tag = tags[index - 1];
                  final selected = tagId == tag.name;
                  return ChoiceChip(
                    label: Text(tag.name),
                    selected: selected,
                    onSelected: (_) => onTagChanged(tag.name),
                    selectedColor: const Color(0xFF27ae60),
                    labelStyle: FontUtils.poppins(
                      fontSize: 12,
                      color: selected ? Colors.white : textColor,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

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
  final bool showSource;
  final String emptyLabel;

  const MusicBoardList({
    super.key,
    required this.boards,
    required this.onTap,
    this.showSource = false,
    this.emptyLabel = '当前音源暂无排行榜数据',
  });

  @override
  Widget build(BuildContext context) {
    if (boards.isEmpty) {
      return Center(
        child: Text(emptyLabel, style: FontUtils.poppins(color: const Color(0xFF7f8c8d))),
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
                        if (musicBoardSubtitle(board, showSource: showSource)
                            .isNotEmpty)
                          Text(
                            musicBoardSubtitle(board, showSource: showSource),
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
  final bool hasMore;
  final ValueNotifier<bool>? loadingMore;
  final VoidCallback? onLoadMore;
  final bool showSource;
  final String emptyLabel;

  const MusicPlaylistGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.hasMore = false,
    this.loadingMore,
    this.onLoadMore,
    this.showSource = false,
    this.emptyLabel = '当前音源暂无推荐歌单数据',
  });

  @override
  Widget build(BuildContext context) {
    return PagedCatalogScroll(
      itemCount: items.length,
      hasMore: hasMore,
      loadingMoreListenable: loadingMore,
      onLoadMore: onLoadMore ?? () {},
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      empty: Center(
        child: Text(emptyLabel, style: FontUtils.poppins(color: const Color(0xFF7f8c8d))),
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          key: ValueKey('${item.source}-${item.id}'),
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
                musicPlaylistSubtitle(item, showSource: showSource),
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
