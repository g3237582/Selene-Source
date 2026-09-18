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
      final detail = await MangaService.getDetail(
        mangaId: widget.item.id,
        sourceId: widget.item.sourceId,
        title: widget.item.title,
        cover: widget.item.cover,
        sourceName: widget.item.sourceName,
      );
      final shelf = await MangaService.getShelf();
      if (!mounted) return;
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : detail == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 110,
                                height: 150,
                                child: AuthenticatedImage(url: detail.cover),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    detail.title,
                                    style: FontUtils.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (detail.author.isNotEmpty)
                                    Text(detail.author),
                                  if (detail.status.isNotEmpty)
                                    Text(detail.status),
                                  Text(
                                    detail.sourceName,
                                    style: FontUtils.poppins(
                                      color: theme.isDarkMode
                                          ? const Color(0xFFb0b0b0)
                                          : const Color(0xFF7f8c8d),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (detail.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(detail.description),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          '目录 ${detail.chapters.length}',
                          style: FontUtils.poppins(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        ...detail.chapters.map(
                          (chapter) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(chapter.name),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openChapter(chapter),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
