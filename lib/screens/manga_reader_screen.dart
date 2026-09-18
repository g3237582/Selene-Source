import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/manga.dart';
import '../services/manga_service.dart';
import '../widgets/authenticated_image.dart';

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

  Future<void> _loadPages() async {
    setState(() {
      _loading = true;
      _error = null;
      _pageIndex = 0;
    });
    try {
      final pages = await MangaService.getPages(_chapter.id);
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _loading = false;
      });
      await MangaService.saveHistory(
        manga: widget.manga,
        chapter: _chapter,
        pageIndex: 0,
        pageCount: pages.length,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
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

  void _switchChapter(int offset) {
    final current = widget.chapters.indexWhere((item) => item.id == _chapter.id);
    final next = current + offset;
    if (next < 0 || next >= widget.chapters.length) return;
    _chapter = widget.chapters[next];
    _loadPages();
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
            GestureDetector(
              onTap: () => setState(() => _showChrome = !_showChrome),
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 3,
                    child: Center(
                      child: AuthenticatedImage(
                        url: _pages[index],
                        fit: BoxFit.contain,
                        width: MediaQuery.of(context).size.width,
                      ),
                    ),
                  );
                },
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
