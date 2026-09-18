import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/books_service.dart';
import '../services/theme_service.dart';
import '../utils/font_utils.dart';
import '../utils/html_text.dart';

class BookReaderScreen extends StatefulWidget {
  final BookItem book;
  final List<BookChapter> chapters;
  final BookChapter initialChapter;

  const BookReaderScreen({
    super.key,
    required this.book,
    required this.chapters,
    required this.initialChapter,
  });

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  late BookChapter _chapter;
  String _content = '';
  bool _loading = true;
  String? _error;
  double _fontSize = 18;

  @override
  void initState() {
    super.initState();
    _chapter = widget.initialChapter;
    _loadChapter();
  }

  Future<void> _loadChapter() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chapter = await BooksService.getChapter(
        book: widget.book,
        chapter: _chapter,
      );
      await BooksService.saveHistory(book: widget.book, chapter: _chapter);
      if (!mounted) return;
      setState(() {
        _content = stripHtml(chapter.content);
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

  void _switchChapter(int offset) {
    final current =
        widget.chapters.indexWhere((item) => item.href == _chapter.href);
    final next = current + offset;
    if (next < 0 || next >= widget.chapters.length) return;
    _chapter = widget.chapters[next];
    _loadChapter();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_chapter.title, style: FontUtils.poppins(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(14, 28)),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(14, 28)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: SelectableText(
                          _content.isEmpty ? '本章暂无正文' : _content,
                          style: FontUtils.poppins(
                            fontSize: _fontSize,
                            height: 1.7,
                            color: theme.isDarkMode
                                ? Colors.white
                                : const Color(0xFF2c3e50),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _switchChapter(-1),
                                child: const Text('上一章'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _switchChapter(1),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF27ae60),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('下一章'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
