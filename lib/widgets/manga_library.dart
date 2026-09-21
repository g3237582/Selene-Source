import 'package:flutter/material.dart';

import '../manga/manga_progress.dart';
import '../models/manga.dart';
import '../utils/font_utils.dart';
import 'authenticated_image.dart';

typedef OpenMangaCallback = void Function(
  MangaItem item, {
  bool resumeIfPossible,
});

String mangaShelfProgressLabel(
  MangaShelfItem item,
  List<MangaReadRecord> history,
) {
  final progress = findMangaProgress(history, item.sourceId, item.mangaId);
  if (progress != null) {
    return mangaProgressLabel(progress);
  }
  if (item.lastChapterName.isEmpty) {
    return item.sourceName;
  }
  return item.lastChapterName;
}

class MangaLibraryPane extends StatelessWidget {
  final List<MangaShelfItem> shelf;
  final List<MangaReadRecord> history;
  final OpenMangaCallback onTap;

  const MangaLibraryPane({
    super.key,
    required this.shelf,
    required this.history,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text('书架', style: FontUtils.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
        if (shelf.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Text('书架是空的', style: FontUtils.poppins(color: const Color(0xFF7f8c8d))),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = shelf[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 48,
                      height: 64,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AuthenticatedImage(url: item.cover),
                      ),
                    ),
                    title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      mangaShelfProgressLabel(item, history),
                      maxLines: 1,
                    ),
                    onTap: () => onTap(item.toItem()),
                  );
                },
                childCount: shelf.length,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text('阅读历史', style: FontUtils.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
        if (history.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
              child: Text('暂无历史', style: FontUtils.poppins(color: const Color(0xFF7f8c8d))),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = history[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 48,
                      height: 64,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AuthenticatedImage(url: item.cover),
                      ),
                    ),
                    title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(mangaProgressLabel(item), maxLines: 1),
                    onTap: () => onTap(item.toItem(), resumeIfPossible: true),
                  );
                },
                childCount: history.length,
              ),
            ),
          ),
      ],
    );
  }
}
