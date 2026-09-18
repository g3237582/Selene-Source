import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/manga.dart';
import '../services/manga_service.dart';
import '../services/theme_service.dart';
import '../utils/font_utils.dart';
import '../widgets/authenticated_image.dart';
import 'manga_reader_screen.dart';

class MangaDetailScreen extends StatefulWidget {
  final MangaItem item;

  const MangaDetailScreen({super.key, required this.item});

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  MangaDetail? _detail;
  bool _loading = true;
  bool _onShelf = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        MangaService.getDetail(
          mangaId: widget.item.id,
          sourceId: widget.item.sourceId,
          title: widget.item.title,
          cover: widget.item.cover,
          sourceName: widget.item.sourceName,
        ),
        MangaService.getShelf(),
      ]);
      if (!mounted) return;
      final detail = results[0] as MangaDetail;
      final shelf = results[1] as List<MangaShelfItem>;
      setState(() {
        _detail = detail;
        _onShelf = shelf.any(
          (item) => item.sourceId == detail.sourceId && item.mangaId == detail.id,
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _toggleShelf() async {
    final detail = _detail;
    if (detail == null) return;
    try {
      if (_onShelf) {
        await MangaService.removeFromShelf(detail.sourceId, detail.id);
      } else {
        await MangaService.addToShelf(detail);
      }
      if (!mounted) return;
      setState(() => _onShelf = !_onShelf);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _openChapter(MangaChapter chapter) {
    final detail = _detail;
    if (detail == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MangaReaderScreen(
          manga: detail,
          chapters: detail.chapters,
          initialChapter: chapter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final detail = _detail;
    final muted = theme.isDarkMode
        ? const Color(0xFFb0b0b0)
        : const Color(0xFF7f8c8d);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.title, style: FontUtils.poppins(fontSize: 16)),
        actions: [
          IconButton(
            onPressed: detail == null ? null : _toggleShelf,
            icon: Icon(_onShelf ? Icons.bookmark : Icons.bookmark_border),
          ),
        ],
      ),
      body: _error != null && detail == null
          ? Center(child: Text(_error!))
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: _MangaHeader(
                      title: detail?.title ?? widget.item.title,
                      cover: detail?.cover ?? widget.item.cover,
                      author: detail?.author ?? '',
                      status: detail?.status ?? '',
                      sourceName: detail?.sourceName ?? widget.item.sourceName,
                      description: detail?.description ?? '',
                      muted: muted,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      detail == null
                          ? '目录'
                          : '目录 ${detail.chapters.length}',
                      style: FontUtils.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (detail == null || detail.chapters.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error ?? '暂无章节',
                        style: FontUtils.poppins(color: muted),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final chapter = detail.chapters[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(chapter.name),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openChapter(chapter),
                          );
                        },
                        childCount: detail.chapters.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MangaHeader extends StatelessWidget {
  final String title;
  final String cover;
  final String author;
  final String status;
  final String sourceName;
  final String description;
  final Color muted;

  const _MangaHeader({
    required this.title,
    required this.cover,
    required this.author,
    required this.status,
    required this.sourceName,
    required this.description,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 110,
                height: 150,
                child: AuthenticatedImage(url: cover),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: FontUtils.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (author.isNotEmpty) Text(author),
                  if (status.isNotEmpty) Text(status),
                  Text(
                    sourceName,
                    style: FontUtils.poppins(color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(description),
        ],
      ],
    );
  }
}
