import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/book_file.dart';
import '../services/book_file_service.dart';
import '../services/book_read_access.dart';
import '../services/books_service.dart';
import '../utils/book_catalog.dart';
import '../utils/book_file_open.dart';
import '../utils/epub_extract.dart';
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
  BookChaptersNotApplicable? _fileHints;
  BookReadManifest? _manifest;
  bool _loadingChapters = true;
  bool _openingFile = false;
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
      _fileHints = null;
      _manifest = null;
    });

    final access = await BookReadAccess.load(_book);
    if (!mounted) return;
    setState(() {
      _book = access.book;
      _chapters = access.chapters;
      _fileHints = access.fileHints;
      _manifest = access.manifest;
      _loadingChapters = false;
      _error = access.chapters.isEmpty && !access.isFileBook
          ? access.error
          : null;
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

  Future<void> _openFileBook({required bool preferInApp}) async {
    final hints = _fileHints;
    if (hints == null || _openingFile) {
      return;
    }
    setState(() => _openingFile = true);
    try {
      final bytes = await BookFileService.downloadFile(
        book: _book,
        hints: hints,
        manifest: _manifest,
      );
      final format = _manifest?.format.isNotEmpty == true
          ? _manifest!.format
          : hints.format;
      if (preferInApp && format == 'epub') {
        final extracted = extractEpubChapters(bytes);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookReaderScreen(
              book: _book.copyWith(format: 'epub'),
              chapters: [for (final item in extracted) item.chapter],
              initialChapter: extracted.first.chapter,
              localContents: epubChapterContents(extracted),
            ),
          ),
        );
        return;
      }
      await openBookBytesWithSystem(
        bytes: bytes,
        title: _book.title,
        format: format,
        remoteUrl: _manifest?.fileUrl,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _openingFile = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileBook = _fileHints != null;
    final format = (_manifest?.format.isNotEmpty == true
            ? _manifest!.format
            : (_fileHints?.format ?? _book.format))
        .toUpperCase();
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
                fileBook
                    ? (format == 'PDF' ? '电子书 PDF' : '电子书 EPUB')
                    : (_chapters.isEmpty ? '章节' : '章节 ${_chapters.length}'),
                style: FontUtils.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_loadingChapters)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (fileBook)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: _FileBookPanel(
                  message: bookFileBookMessage(_book, format: format),
                  format: format,
                  opening: _openingFile,
                  onRead: () => _openFileBook(preferInApp: format != 'PDF'),
                  onSystemOpen: () => _openFileBook(preferInApp: false),
                ),
              ),
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

class _FileBookPanel extends StatelessWidget {
  final String message;
  final String format;
  final bool opening;
  final VoidCallback onRead;
  final VoidCallback onSystemOpen;

  const _FileBookPanel({
    required this.message,
    required this.format,
    required this.opening,
    required this.onRead,
    required this.onSystemOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: 20),
        if (opening)
          const Center(child: CircularProgressIndicator())
        else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRead,
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(format == 'PDF' ? '打开 PDF' : '阅读 EPUB'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27ae60),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSystemOpen,
              icon: const Icon(Icons.open_in_new),
              label: const Text('用其他应用打开'),
            ),
          ),
        ],
      ],
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
