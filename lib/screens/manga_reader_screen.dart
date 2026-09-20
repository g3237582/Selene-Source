import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/manga.dart';
import '../services/manga_service.dart';
import '../utils/remote_error.dart';
import '../widgets/authenticated_image.dart';

enum MangaReaderTapZone { previous, chrome, next }

class MangaReaderTurn {
  final int? pageIndex;
  final int chapterOffset;
  final bool openAtEnd;

  const MangaReaderTurn({
    this.pageIndex,
    this.chapterOffset = 0,
    this.openAtEnd = false,
  });
}

MangaReaderTurn resolveMangaReaderTurn({
  required int pageIndex,
  required int pageCount,
  required int chapterIndex,
  required int chapterCount,
  required int delta,
}) {
  if (delta > 0) {
    if (pageIndex + 1 < pageCount) {
      return MangaReaderTurn(pageIndex: pageIndex + 1);
    }
    if (chapterIndex + 1 < chapterCount) {
      return const MangaReaderTurn(chapterOffset: 1);
    }
    return const MangaReaderTurn();
  }
  if (delta < 0) {
    if (pageIndex > 0) {
      return MangaReaderTurn(pageIndex: pageIndex - 1);
    }
    if (chapterIndex > 0) {
      return const MangaReaderTurn(chapterOffset: -1, openAtEnd: true);
    }
  }
  return const MangaReaderTurn();
}

int? mangaReaderOverscrollTurnDelta({
  required Axis axis,
  required double overscroll,
  required bool fromDrag,
  required int pageIndex,
  required int pageCount,
}) {
  if (axis != Axis.horizontal || !fromDrag) {
    return null;
  }
  if (overscroll < 0 && pageIndex == 0) {
    return -1;
  }
  if (overscroll > 0 && pageIndex == pageCount - 1) {
    return 1;
  }
  return null;
}

MangaReaderTapZone mangaReaderTapZone(double x, double width) {
  if (width <= 0) {
    return MangaReaderTapZone.chrome;
  }
  if (x < width / 3) {
    return MangaReaderTapZone.previous;
  }
  if (x > width * 2 / 3) {
    return MangaReaderTapZone.next;
  }
  return MangaReaderTapZone.chrome;
}

class MangaReaderScreen extends StatefulWidget {
  final MangaItem manga;
  final List<MangaChapter> chapters;
  final MangaChapter initialChapter;

  const MangaReaderScreen({
    super.key,
    required this.manga,
    required this.chapters,
    required this.initialChapter,
  });

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  late MangaChapter _chapter;
  final PageController _pageController = PageController();
  List<String> _pages = [];
  bool _loading = true;
  String? _error;
  int _pageIndex = 0;
  bool _showChrome = true;
  bool _edgeTurnLocked = false;
  Offset? _pointerDown;

  @override
  void initState() {
    super.initState();
    _chapter = widget.initialChapter;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadPages();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPages({bool openAtEnd = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _pageIndex = 0;
      _edgeTurnLocked = true;
    });
    try {
      final pages = await MangaService.getPages(_chapter.id);
      if (!mounted) return;
      final target = pages.isEmpty
          ? 0
          : (openAtEnd ? pages.length - 1 : 0);
      setState(() {
        _pages = pages;
        _loading = false;
        _pageIndex = target;
        _edgeTurnLocked = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(target);
      });
      await MangaService.saveHistory(
        manga: widget.manga,
        chapter: _chapter,
        pageIndex: target,
        pageCount: pages.length,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = sanitizeRemoteError(error, fallback: '获取章节图片失败');
        _loading = false;
        _edgeTurnLocked = false;
      });
    }
  }

  Future<void> _onPageChanged(int index) async {
    setState(() => _pageIndex = index);
    await MangaService.saveHistory(
      manga: widget.manga,
      chapter: _chapter,
      pageIndex: index,
      pageCount: _pages.length,
    );
  }

  void _switchChapter(int offset, {bool openAtEnd = false}) {
    final current = widget.chapters.indexWhere((item) => item.id == _chapter.id);
    final next = current + offset;
    if (next < 0 || next >= widget.chapters.length) return;
    _chapter = widget.chapters[next];
    _loadPages(openAtEnd: openAtEnd);
  }

  void _turnPage(int delta) {
    final chapterIndex =
        widget.chapters.indexWhere((item) => item.id == _chapter.id);
    final turn = resolveMangaReaderTurn(
      pageIndex: _pageIndex,
      pageCount: _pages.length,
      chapterIndex: chapterIndex < 0 ? 0 : chapterIndex,
      chapterCount: widget.chapters.length,
      delta: delta,
    );
    if (turn.chapterOffset != 0) {
      if (_edgeTurnLocked) {
        return;
      }
      _edgeTurnLocked = true;
      _switchChapter(turn.chapterOffset, openAtEnd: turn.openAtEnd);
      return;
    }
    final next = turn.pageIndex;
    if (next == null) {
      return;
    }
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_loading || _edgeTurnLocked || _pages.isEmpty) {
      return false;
    }
    if (notification is! OverscrollNotification) {
      return false;
    }
    final delta = mangaReaderOverscrollTurnDelta(
      axis: notification.metrics.axis,
      overscroll: notification.overscroll,
      fromDrag: notification.dragDetails != null,
      pageIndex: _pageIndex,
      pageCount: _pages.length,
    );
    if (delta == null) {
      return false;
    }
    _turnPage(delta);
    return false;
  }

  void _onTapAt(Offset localPosition, Size size) {
    switch (mangaReaderTapZone(localPosition.dx, size.width)) {
      case MangaReaderTapZone.previous:
        _turnPage(-1);
      case MangaReaderTapZone.next:
        _turnPage(1);
      case MangaReaderTapZone.chrome:
        setState(() => _showChrome = !_showChrome);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDown = event.localPosition;
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _pointerDown;
    _pointerDown = null;
    if (down == null) {
      return;
    }
    if ((event.localPosition - down).distance > 18) {
      return;
    }
    _onTapAt(event.localPosition, MediaQuery.sizeOf(context));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: Text(_error!, style: const TextStyle(color: Colors.white70)),
            )
          else
            NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _onPointerDown,
                onPointerUp: _onPointerUp,
                onPointerCancel: (_) => _pointerDown = null,
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.horizontal,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: AuthenticatedImage(
                            url: _pages[index],
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topCenter,
                            width: constraints.maxWidth,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          if (_showChrome)
            SafeArea(
              child: Column(
                children: [
                  Container(
                    color: Colors.black54,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            '${_chapter.name}  ${_pages.isEmpty ? '' : '${_pageIndex + 1}/${_pages.length}'}',
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous, color: Colors.white),
                          onPressed: () => _switchChapter(-1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, color: Colors.white),
                          onPressed: () => _switchChapter(1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
