import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../manga/manga_progress.dart';
import '../models/manga.dart';
import '../services/manga_service.dart';
import '../utils/remote_error.dart';
import '../widgets/authenticated_image.dart';

enum MangaReaderTapZone { previous, chrome, next }

class MangaReaderKeys {
  static const pageViewport = Key('manga-reader-page-viewport');
  static const chromeBar = Key('manga-reader-chrome-bar');
}

/// Height of the top control row (close / title / prev / next).
///
/// The page display rect starts at the bottom of this band so manga pixels
/// never draw under the buttons.
const double mangaReaderChromeBarHeight = 48;

/// Status-bar / home-indicator inset that still works in immersive mode.
///
/// `SystemUiMode.immersiveSticky` zeros [MediaQuery.padding] while the cutout
/// and system bars remain in [MediaQuery.viewPadding]. Taking the max keeps
/// chrome and page pixels out from under the status bar in both modes.
EdgeInsets mangaReaderSafeInset({
  required EdgeInsets padding,
  required EdgeInsets viewPadding,
}) {
  return EdgeInsets.only(
    top: math.max(padding.top, viewPadding.top),
    bottom: math.max(padding.bottom, viewPadding.bottom),
    left: math.max(padding.left, viewPadding.left),
    right: math.max(padding.right, viewPadding.right),
  );
}

/// Content display rect: safe insets plus the reserved top chrome bar.
///
/// Short pages center in this rect. Tall pages pin to its top edge and
/// scroll inside it, so they never enter the button region.
EdgeInsets mangaReaderContentInset({
  required EdgeInsets safeInset,
  double chromeBarHeight = mangaReaderChromeBarHeight,
}) {
  return EdgeInsets.only(
    top: safeInset.top + chromeBarHeight,
    bottom: safeInset.bottom,
    left: safeInset.left,
    right: safeInset.right,
  );
}

/// Vertical offset of a fitted page inside the content display rect.
double mangaReaderPageTopOffset({
  required double pageHeight,
  required double displayHeight,
}) {
  if (pageHeight <= 0 || displayHeight <= 0 || pageHeight >= displayHeight) {
    return 0;
  }
  return (displayHeight - pageHeight) / 2;
}

/// Scrollable page host: center when shorter than the viewport, pin to top
/// and scroll when taller.
class MangaReaderPageScroller extends StatelessWidget {
  final Widget child;

  const MangaReaderPageScroller({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

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
  final int initialPageIndex;

  const MangaReaderScreen({
    super.key,
    required this.manga,
    required this.chapters,
    required this.initialChapter,
    this.initialPageIndex = 0,
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
    _loadPages(resumePage: widget.initialPageIndex);
  }

  @override
  void dispose() {
    _persistProgress();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _persistProgress() async {
    if (_pages.isEmpty) {
      return;
    }
    try {
      await MangaService.saveHistory(
        manga: widget.manga,
        chapter: _chapter,
        pageIndex: _pageIndex,
        pageCount: _pages.length,
      );
    } catch (_) {}
  }

  Future<void> _loadPages({bool openAtEnd = false, int? resumePage}) async {
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
          : openAtEnd
              ? pages.length - 1
              : clampMangaPageIndex(
                  pageIndex: resumePage ?? 0,
                  pageCount: pages.length,
                );
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
    try {
      await MangaService.saveHistory(
        manga: widget.manga,
        chapter: _chapter,
        pageIndex: index,
        pageCount: _pages.length,
      );
    } catch (_) {}
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
    final inset = mangaReaderSafeInset(
      padding: MediaQuery.paddingOf(context),
      viewPadding: MediaQuery.viewPaddingOf(context),
    );
    final contentInset = mangaReaderContentInset(safeInset: inset);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Listener stays full-screen so left/center/right tap zones are
          // unchanged. Visual pages use the content rect below the chrome
          // bar (and inside safe insets) so they never draw under buttons.
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            onPointerCancel: (_) => _pointerDown = null,
            child: Padding(
              key: MangaReaderKeys.pageViewport,
              padding: contentInset,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: _onScrollNotification,
                          child: PageView.builder(
                            controller: _pageController,
                            scrollDirection: Axis.horizontal,
                            onPageChanged: _onPageChanged,
                            itemCount: _pages.length,
                            itemBuilder: (context, index) {
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  return MangaReaderPageScroller(
                                    child: AuthenticatedImage(
                                      url: _pages[index],
                                      fit: BoxFit.fitWidth,
                                      alignment: Alignment.center,
                                      width: constraints.maxWidth,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
            ),
          ),
          if (_showChrome)
            Column(
              children: [
                Container(height: inset.top, color: Colors.black54),
                Padding(
                  padding: EdgeInsets.only(
                    left: inset.left,
                    right: inset.right,
                  ),
                  child: Container(
                    key: MangaReaderKeys.chromeBar,
                    height: mangaReaderChromeBarHeight,
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
                ),
              ],
            ),
        ],
      ),
    );
  }
}
