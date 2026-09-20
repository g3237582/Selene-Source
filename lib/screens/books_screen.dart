import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../search/search_list_paging.dart';
import '../services/books_service.dart';
import '../services/theme_service.dart';
import '../utils/book_catalog.dart';
import '../utils/font_utils.dart';
import '../utils/paged_list.dart';
import '../widgets/authenticated_image.dart';
import '../widgets/search_pagination_bar.dart';
import 'book_detail_screen.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<BookSource> _sources = [];
  List<BookNavLink> _navigation = [];
  String? _sourceId;
  String _catalogHref = '';
  String _nextHref = '';
  List<BookItem> _loadedItems = [];
  List<BookItem> _items = [];
  int _page = 1;
  bool _remoteHasMore = true;
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
    await Future.wait([
      _loadSources(),
      _loadShelf(),
    ]);
    if (!mounted) return;
    await _reloadDiscover();
  }

  Future<void> _reloadDiscover() {
    _loadedItems = [];
    _nextHref = '';
    _remoteHasMore = true;
    return _loadDiscover(page: 1);
  }

  Future<void> _loadSources() async {
    try {
      final sources = await BooksService.getSources();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _sourceId ??= sources.isNotEmpty ? sources.first.id : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadDiscover({required int page}) async {
    final query = _searchController.text.trim();
    if (query.isEmpty && _sourceId == null) {
      setState(() {
        _loading = false;
        _loadedItems = [];
        _items = [];
        _page = 1;
        _remoteHasMore = false;
      });
      return;
    }

    final needed = page * SearchListPaging.pageSize;
    if (_loadedItems.length >= needed || !_remoteHasMore) {
      _applyDiscoverPage(page);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (query.isNotEmpty && _loadedItems.isEmpty) {
        _loadedItems = await BooksService.search(
          query: query,
          sourceId: _sourceId,
        );
        _remoteHasMore = false;
      } else {
        while (_loadedItems.length < needed && _remoteHasMore) {
          final catalog = await _fetchCatalog(firstBatch: _loadedItems.isEmpty);
          if (!mounted) return;
          if (catalog.entries.isEmpty) {
            _remoteHasMore = false;
            break;
          }
          _loadedItems = [..._loadedItems, ...catalog.entries];
          _nextHref = catalog.nextHref;
          _remoteHasMore = catalog.nextHref.isNotEmpty;
        }
      }
      if (!mounted) return;
      _applyDiscoverPage(page);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<BookCatalog> _fetchCatalog({required bool firstBatch}) async {
    if (!firstBatch) {
      return BooksService.catalog(sourceId: _sourceId!, href: _nextHref);
    }
    if (_catalogHref.isEmpty) {
      final root = await BooksService.catalog(sourceId: _sourceId!, href: '');
      _navigation = root.navigation;
      final autoHref = resolveDefaultBookCatalogHref(
        entries: root.entries,
        navigation: root.navigation,
      );
      if (autoHref != null) {
        _catalogHref = autoHref;
        return BooksService.catalog(sourceId: _sourceId!, href: autoHref);
      }
      return root;
    }
    return BooksService.catalog(sourceId: _sourceId!, href: _catalogHref);
  }

  void _applyDiscoverPage(int page) {
    final pageCount = displayPageCount(
      loadedCount: _loadedItems.length,
      pageSize: SearchListPaging.pageSize,
      remoteHasMore: _remoteHasMore,
    );
    final current = SearchListPaging.clampPage(page, pageCount);
    setState(() {
      _items = SearchListPaging.pageOf(_loadedItems, current);
      _page = current;
      _loading = false;
      _error = null;
    });
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
              onSubmitted: (_) => _reloadDiscover(),
              decoration: InputDecoration(
                hintText: '搜索电子书',
                hintStyle: FontUtils.poppins(color: muted, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: muted),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Color(0xFF27ae60)),
                  onPressed: _reloadDiscover,
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
                      setState(() {
                        _sourceId = source.id;
                        _catalogHref = '';
                      });
                      _reloadDiscover();
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
          if (_navigation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final nav = _navigation[index];
                    final selected = nav.href == _catalogHref;
                    return ChoiceChip(
                      label: Text(nav.title),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _catalogHref = nav.href);
                        _reloadDiscover();
                      },
                      selectedColor: const Color(0xFF27ae60),
                      labelStyle: FontUtils.poppins(
                        fontSize: 12,
                        color: selected ? Colors.white : textColor,
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _navigation.length,
                ),
              ),
            ),
        ],
        Expanded(
          child: _tab == 0
              ? _buildDiscover(muted)
              : _BookGrid(items: _shelf, onTap: _openBook),
        ),
      ],
    );
  }

  Widget _buildDiscover(Color muted) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: FontUtils.poppins(color: muted)),
        ),
      );
    }
    final pageCount = displayPageCount(
      loadedCount: _loadedItems.length,
      pageSize: SearchListPaging.pageSize,
      remoteHasMore: _remoteHasMore,
    );
    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _BookGrid(items: _items, onTap: _openBook),
        ),
        if (_items.isNotEmpty)
          SearchPaginationBar(
            totalItems: _items.length,
            page: _page,
            pageCount: pageCount,
            summary: remoteSummaryText(
              pageItemCount: _items.length,
              page: _page,
              pageCount: pageCount,
            ),
            onPageChanged: (next) => _loadDiscover(page: next),
          ),
      ],
    );
  }
}

class _BookGrid extends StatelessWidget {
  final List<BookItem> items;
  final ValueChanged<BookItem> onTap;

  const _BookGrid({
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text('暂无书籍', style: FontUtils.poppins(color: const Color(0xFF7f8c8d))),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => onTap(item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.cover.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFF2c3e50),
                          child: Center(
                            child: Icon(Icons.menu_book, color: Colors.white70),
                          ),
                        )
                      : AuthenticatedImage(url: item.cover),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FontUtils.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}
