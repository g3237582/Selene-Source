import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/books_service.dart';
import '../services/theme_service.dart';
import '../utils/font_utils.dart';
import '../widgets/authenticated_image.dart';
import 'book_detail_screen.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<BookSource> _sources = [];
  String? _sourceId;
  List<BookItem> _items = [];
  List<BookItem> _shelf = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sources = await BooksService.getSources();
      if (!mounted) return;
      _sources = sources;
      _sourceId = sources.isNotEmpty ? sources.first.id : null;
      await Future.wait([_loadBooks(), _loadShelf()]);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadBooks() async {
    try {
      final query = _searchController.text.trim();
      List<BookItem> items;
      if (query.isNotEmpty) {
        items = await BooksService.search(query: query, sourceId: _sourceId);
      } else if (_sourceId != null) {
        try {
          items = await BooksService.catalog(sourceId: _sourceId!);
        } catch (_) {
          items = [];
        }
      } else {
        items = [];
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadShelf() async {
    try {
      final shelf = await BooksService.getShelf();
      if (!mounted) return;
      setState(() => _shelf = shelf);
    } catch (_) {}
  }

  void _openBook(BookItem book) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final textColor =
        theme.isDarkMode ? Colors.white : const Color(0xFF2c3e50);
    final muted = theme.isDarkMode
        ? const Color(0xFFb0b0b0)
        : const Color(0xFF7f8c8d);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('发现'),
                selected: _tab == 0,
                onSelected: (_) => setState(() => _tab = 0),
                selectedColor: const Color(0xFF27ae60),
                labelStyle: FontUtils.poppins(
                  color: _tab == 0 ? Colors.white : muted,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('书架'),
                selected: _tab == 1,
                onSelected: (_) => setState(() => _tab = 1),
                selectedColor: const Color(0xFF27ae60),
                labelStyle: FontUtils.poppins(
                  color: _tab == 1 ? Colors.white : muted,
                ),
              ),
            ],
          ),
        ),
        if (_tab == 0) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loadBooks(),
              decoration: InputDecoration(
                hintText: '搜索电子书',
                hintStyle: FontUtils.poppins(color: muted, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: muted),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Color(0xFF27ae60)),
                  onPressed: _loadBooks,
                ),
                filled: true,
                fillColor:
                    theme.isDarkMode ? const Color(0xFF1e1e1e) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: FontUtils.poppins(color: textColor, fontSize: 14),
            ),
          ),
          if (_sources.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final source = _sources[index];
                  final selected = source.id == _sourceId;
                  return ChoiceChip(
                    label: Text(source.name),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _sourceId = source.id);
                      _loadBooks();
                    },
                    selectedColor: const Color(0xFF27ae60),
                    labelStyle: FontUtils.poppins(
                      fontSize: 12,
                      color: selected ? Colors.white : textColor,
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _sources.length,
              ),
            ),
        ],
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _tab == 0
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, style: FontUtils.poppins(color: muted)),
                    ))
                  : _tab == 0
                      ? _BookList(items: _items, onTap: _openBook)
                      : _BookList(items: _shelf, onTap: _openBook),
        ),
      ],
    );
  }
}

class _BookList extends StatelessWidget {
  final List<BookItem> items;
  final ValueChanged<BookItem> onTap;

  const _BookList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text('暂无书籍', style: FontUtils.poppins(color: const Color(0xFF7f8c8d))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final book = items[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 48,
            height: 64,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: book.cover.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFF2c3e50),
                      child: Icon(Icons.menu_book, color: Colors.white70),
                    )
                  : AuthenticatedImage(url: book.cover),
            ),
          ),
          title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [book.author, book.sourceName]
                .where((item) => item.isNotEmpty)
                .join(' · '),
            maxLines: 1,
          ),
          onTap: () => onTap(book),
        );
      },
    );
  }
}
