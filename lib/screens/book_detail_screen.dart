import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/books_service.dart';
import '../utils/book_catalog.dart';
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
  bool _loadingChapters = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadingChapters = true;
      _error = null;
    });

    final detailFuture = BooksService.getDetail(_book);
    final chaptersFuture = BooksService.getChapters(_book);

    BookItem detail = _book;
    List<BookChapter> chapters = [];
    String? error;

    try {
      detail = await detailFuture;
    } catch (err) {
      error = err.toString().replaceFirst('Exception: ', '');
    }

    try {
      chapters = await chaptersFuture;
    } catch (_) {
      try {
        chapters = await BooksService.getChapters(detail);
      } catch (err) {
        error ??= err.toString().replaceFirst('Exception: ', '');
      }
    }

    if (chapters.isEmpty &&
        detail.detailHref.isNotEmpty &&
        detail.detailHref != widget.book.detailHref) {
      try {
        chapters = await BooksService.getChapters(detail);
      } catch (err) {
        error ??= err.toString().replaceFirst('Exception: ', '');
      }
    }

    if (!mounted) return;
    setState(() {
      _book = detail;
      _chapters = chapters;
      _loadingChapters = false;
      if (chapters.isEmpty) {
        _error = error;
      }
    });
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
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _BookHeader(book: _book),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                _chapters.isEmpty ? '章节' : '章节 ${_chapters.length}',
                style: FontUtils.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_loadingChapters)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_chapters.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error ?? bookEmptyChaptersMessage(_book),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final chapter = _chapters[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(chapter.title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openChapter(chapter),
                    );
                  },
                  childCount: _chapters.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookHeader extends StatelessWidget {
  final BookItem book;

  const _BookHeader({required this.book});

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
                width: 96,
                height: 128,
                child: book.cover.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFF2c3e50),
                        child: Icon(Icons.menu_book, color: Colors.white70),
                      )
                    : AuthenticatedImage(url: book.cover),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: FontUtils.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (book.author.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(book.author),
                  ],
                  Text(book.sourceName),
                ],
              ),
            ),
          ],
        ),
        if (book.summary.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(book.summary),
        ],
      ],
    );
  }
}
