import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../manga/manga_progress.dart';
import '../models/manga.dart';
import '../services/manga_service.dart';
import '../services/theme_service.dart';
import '../utils/font_utils.dart';
import '../utils/remote_error.dart';
import '../widgets/authenticated_image.dart';
import 'manga_reader_screen.dart';

class MangaDetailScreen extends StatefulWidget {
  final MangaItem item;
  final bool resumeIfPossible;

  const MangaDetailScreen({
    super.key,
    required this.item,
    this.resumeIfPossible = false,
  });

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  MangaDetail? _detail;
  MangaReadRecord? _progress;
  bool _loading = true;
  bool _onShelf = false;
  bool _didAutoResume = false;
  String? _error;
  RemoteErrorInfo? _remoteError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool confirmAdult = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _remoteError = null;
    });
    try {
      final detail = confirmAdult
          ? await MangaService.sendCommand(
              command: kConfirmAdultCommand,
              mangaId: widget.item.id,
              sourceId: widget.item.sourceId,
              title: widget.item.title,
              cover: widget.item.cover,
              sourceName: widget.item.sourceName,
            )
          : await MangaService.getDetail(
              mangaId: widget.item.id,
              sourceId: widget.item.sourceId,
              title: widget.item.title,
              cover: widget.item.cover,
              sourceName: widget.item.sourceName,
            );
      var onShelf = _onShelf;
      try {
        final shelf = await MangaService.getShelf();
        onShelf = shelf.any(
          (item) => item.sourceId == detail.sourceId && item.mangaId == detail.id,
        );
      } catch (_) {}
      MangaReadRecord? progress;
      try {
        progress = await MangaService.getProgress(
          sourceId: detail.sourceId,
          mangaId: detail.id,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _progress = progress;
        _onShelf = onShelf;
        _loading = false;
      });
      _maybeAutoResume(detail, progress);
    } catch (error) {
      if (!mounted) return;
      final parsed = parseRemoteError(error, fallback: '获取漫画详情失败');
      setState(() {
        _remoteError = parsed;
        _error = parsed.message;
        _loading = false;
      });
    }
  }

  Future<void> _runRemoteCommand() async {
    final command = _remoteError?.command;
    if (command == kConfirmAdultCommand) {
      await _load(confirmAdult: true);
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
        SnackBar(content: Text(sanitizeRemoteError(error, fallback: '书架操作失败'))),
      );
    }
  }

  Future<void> _reloadProgress() async {
    final detail = _detail;
    if (detail == null) return;
    try {
      final progress = await MangaService.getProgress(
        sourceId: detail.sourceId,
        mangaId: detail.id,
      );
      if (!mounted) return;
      setState(() => _progress = progress);
    } catch (_) {}
  }

  void _maybeAutoResume(MangaDetail detail, MangaReadRecord? progress) {
    if (!widget.resumeIfPossible || _didAutoResume) {
      return;
    }
    final resume = resolveMangaResume(
      chapters: detail.chapters,
      record: progress,
    );
    if (resume == null) {
      return;
    }
    _didAutoResume = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openChapter(resume.chapter, pageIndex: resume.pageIndex);
    });
  }

  void _openResume() {
    final detail = _detail;
    if (detail == null || detail.chapters.isEmpty) return;
    final resume = resolveMangaResume(
      chapters: detail.chapters,
      record: _progress,
    );
    _openChapter(
      resume?.chapter ?? detail.chapters.first,
      pageIndex: resume?.pageIndex ?? 0,
    );
  }

  void _openChapter(MangaChapter chapter, {int? pageIndex}) {
    final detail = _detail;
    if (detail == null) return;
    final resume = resolveMangaResume(
      chapters: detail.chapters,
      record: _progress,
    );
    final startPage = pageIndex ??
        (resume != null && resume.chapter.id == chapter.id
            ? resume.pageIndex
            : 0);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => MangaReaderScreen(
              manga: detail,
              chapters: detail.chapters,
              initialChapter: chapter,
              initialPageIndex: startPage,
            ),
          ),
        )
        .then((_) => _reloadProgress());
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
      body: CustomScrollView(
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
                if (_progress != null &&
                    detail != null &&
                    detail.chapters.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: FilledButton.icon(
                        onPressed: _openResume,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF27ae60),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.menu_book),
                        label: Text(
                          mangaContinueLabel(_progress!),
                          overflow: TextOverflow.ellipsis,
                        ),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _error ?? '暂无章节',
                            textAlign: TextAlign.center,
                            style: FontUtils.poppins(color: muted),
                          ),
                          if (_remoteError?.hasCommand == true) ...[
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _runRemoteCommand,
                              child: Text(_remoteError!.commandLabel ?? kConfirmAdultLabel),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_error != null) ...[
                            if (_remoteError?.hasCommand != true) const SizedBox(height: 16),
                            TextButton(
                              onPressed: _load,
                              child: const Text('重试'),
                            ),
                          ],
                        ],
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
                          final isCurrent = _progress?.chapterId == chapter.id;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              chapter.name,
                              style: FontUtils.poppins(
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isCurrent
                                    ? const Color(0xFF27ae60)
                                    : null,
                              ),
                            ),
                            trailing: isCurrent
                                ? Text(
                                    '续读',
                                    style: FontUtils.poppins(
                                      color: const Color(0xFF27ae60),
                                      fontSize: 12,
                                    ),
                                  )
                                : const Icon(Icons.chevron_right),
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
