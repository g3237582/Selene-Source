import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/books_service.dart';
import '../utils/font_utils.dart';
import '../widgets/authenticated_image.dart';
import 'book_reader_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final BookItem book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late BookItem _book;
  List<BookChapter> _chapters = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await BooksService.getDetail(_book);
      final chapters = await BooksService.getChapters(detail);
      if (!mounted) return;
      setState(() {
        _book = detail;
        _chapters = chapters;
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

  Future<void> _addToShelf() async {
    try {
      await BooksService.addToShelf(_book);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已加入书架')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _openChapter(BookChapter chapter) {
    if (_chapters.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookReaderScreen(
          book: _book,
          chapters: _chapters,
          initialChapter: chapter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_book.title, style: FontUtils.poppins(fontSize: 16)),
        actions: [
          IconButton(
            onPressed: _addToShelf,
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 96,
                            height: 128,
                            child: _book.cover.isEmpty
                                ? const ColoredBox(
                                    color: Color(0xFF2c3e50),
                                    child: Icon(Icons.menu_book, color: Colors.white70),
                                  )
                                : AuthenticatedImage(url: _book.cover),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _book.title,
                                style: FontUtils.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_book.author.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(_book.author),
                              ],
                              Text(_book.sourceName),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_book.summary.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(_book.summary),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      _chapters.isEmpty ? '章节' : '章节 ${_chapters.length}',
                      style: FontUtils.poppins(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (_chapters.isEmpty)
                      const Text('该书暂不支持章节阅读。EPUB 文件流会在后续版本接入。')
                    else
                      ..._chapters.map(
                        (chapter) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(chapter.title),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openChapter(chapter),
                        ),
                      ),
                  ],
                ),
    );
  }
}
