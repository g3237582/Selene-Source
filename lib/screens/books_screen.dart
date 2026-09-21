import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/books_service.dart';
import '../services/theme_service.dart';
import '../search/search_page_merge.dart';
import '../utils/book_catalog.dart';
import '../utils/font_utils.dart';
import '../utils/paged_list.dart';
import '../widgets/authenticated_image.dart';
import '../widgets/paged_catalog_scroll.dart';
import '../widgets/source_filter_bar.dart';
import 'book_detail_screen.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _loadingMore = ValueNotifier(false);
  List<BookSource> _sources = [];
  List<BookNavLink> _navigation = [];
  String? _sourceId;
  String _catalogHref = '';
  PagedListState<BookItem> _page = const PagedListState();
  List<BookItem> _shelf = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;
  int _discoverGeneration = 0;

  String? get _browseSourceId {
    if (_sourceId != null && _sourceId!.isNotEmpty) {
      return _sourceId;
    }
    for (final source in _sources) {
      if (source.catalogSupported && source.id.isNotEmpty) {
        return source.id;
      }
    }
    return _sources.isNotEmpty ? _sources.first.id : null;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _loadingMore.dispose();
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

  Future<void> _reloadDiscover() => _loadDiscover(reset: true);

  Future<void> _loadSources() async {
    try {
      final sources = await BooksService.getSources();
      if (!mounted) return;
      setState(() => _sources = sources);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadDiscover({required bool reset}) async {
    if (!reset && (_loading || _loadingMore.value || !_page.hasMore)) {
      return;
    }
    final query = _searchController.text.trim();
    if (query.isEmpty && _sourceId == null) {
      setState(() {
        _loading = false;
        _error = null;
        _page = const PagedListState();
        _navigation = [];
      });
      _loadingMore.value = false;
      return;
    }

    final generation = reset ? ++_discoverGeneration : _discoverGeneration;
    final merge = SearchPageMerge<BookItem>(reset: reset);
    if (reset) {
      setState(() {
        _error = null;
        if (_page.items.isEmpty) {
          _loading = true;
        }
      });
    }
    _loadingMore.value = true;

    try {
      late final PagedResult<BookItem> result;
      if (query.isNotEmpty) {
        if (_sourceId == null) {
          final aggregated = await BooksService.searchAll(
            query: query,
            sources: _sources,
            onPartial: (partial) {
              if (!mounted || generation != _discoverGeneration) {
                return;
              }
              setState(() {
                _page = merge.absorb(_page, partial.items);
                _loading = false;
                _error = null;
              });
            },
          );
          if (!mounted || generation != _discoverGeneration) return;
          if (aggregated.errorMessage != null &&
              aggregated.items.isEmpty &&
              !merge.replaced) {
            throw Exception(aggregated.errorMessage);
          }
          setState(() {
            _page = merge.complete(_page, aggregated);
            _loading = false;
            _error = null;
          });
          return;
        } else {
          final items = await BooksService.search(
            query: query,
            sourceId: _sourceId,
          );
          result = PagedResult(items: items, hasMore: false);
        }
      } else {
        final fetched = await _fetchCatalog(firstBatch: reset || _page.items.isEmpty);
        if (!mounted || generation != _discoverGeneration) return;
        if (reset && fetched.catalog.navigation.isNotEmpty) {
          _navigation = fetched.catalog.navigation;
        }
        if (reset && fetched.selectedHref != null) {
          _catalogHref = fetched.selectedHref!;
        }
        result = PagedResult(
          items: fetched.catalog.entries,
          hasMore: fetched.catalog.nextHref.isNotEmpty &&
              fetched.catalog.entries.isNotEmpty,
          nextToken: fetched.catalog.nextHref,
        );
      }
      if (!mounted || generation != _discoverGeneration) return;
      setState(() {
        _page = (reset ? const PagedListState<BookItem>() : _page).append(result);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _discoverGeneration) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    } finally {
      if (generation == _discoverGeneration) {
        _loadingMore.value = false;
      }
    }
  }

  Future<({BookCatalog catalog, String? selectedHref})> _fetchCatalog({
    required bool firstBatch,
  }) async {
    if (!firstBatch) {
      return (
        catalog: await BooksService.catalog(
          sourceId: _browseSourceId!,
          href: _page.nextToken,
        ),
        selectedHref: null,
      );
    }
    if (_catalogHref.isEmpty) {
      final root = await BooksService.catalog(sourceId: _browseSourceId!, href: '');
      final autoHref = resolveDefaultBookCatalogHref(
        entries: root.entries,
        navigation: root.navigation,
      );
      if (autoHref != null) {
        final page = await BooksService.catalog(sourceId: _browseSourceId!, href: autoHref);
        return (
          catalog: BookCatalog(
            entries: page.entries,
            navigation: root.navigation,
            nextHref: page.nextHref,
          ),
          selectedHref: autoHref,
        );
      }
      return (catalog: root, selectedHref: null);
    }
    return (
      catalog: await BooksService.catalog(sourceId: _browseSourceId!, href: _catalogHref),
      selectedHref: null,
    );
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
          SourceFilterBar(
            sources: [
              for (final source in _sources)
                SourceFilterOption(id: source.id, name: source.name),
            ],
            selectedId: _sourceId,
            textColor: textColor,
            onSelected: (sourceId) {
              setState(() {
                _sourceId = sourceId;
                _catalogHref = '';
              });
              _reloadDiscover();
            },
          ),
          if (_sourceId != null &&
              _navigation.isNotEmpty &&
              _searchController.text.trim().isEmpty)
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
    if (shouldReplaceCatalogWithLoader(
      loading: _loading,
      itemCount: _page.items.length,
    )) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _page.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: FontUtils.poppins(color: muted)),
        ),
      );
    }
    final query = _searchController.text.trim();
    return _BookGrid(
      key: ValueKey('books-$_sourceId-$_catalogHref-$query'),
      items: _page.items,
      hasMore: _page.hasMore,
      loadingMore: _loadingMore,
      emptyLabel: query.isEmpty
          ? (_sourceId == null ? '输入关键词进行全源搜索' : '暂无书籍')
          : '未找到相关电子书',
      onLoadMore: () => _loadDiscover(reset: false),
      onTap: _openBook,
    );
  }
}

class _BookGrid extends StatelessWidget {
  final List<BookItem> items;
  final bool hasMore;
  final ValueNotifier<bool>? loadingMore;
  final VoidCallback? onLoadMore;
  final String emptyLabel;
  final ValueChanged<BookItem> onTap;

  const _BookGrid({
    super.key,
    required this.items,
    this.hasMore = false,
    this.loadingMore,
    this.onLoadMore,
    this.emptyLabel = '暂无书籍',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PagedCatalogScroll(
      itemCount: items.length,
      hasMore: hasMore,
      loadingMoreListenable: loadingMore,
      onLoadMore: onLoadMore ?? () {},
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      empty: Center(
        child: Text(emptyLabel, style: FontUtils.poppins(color: const Color(0xFF7f8c8d))),
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          key: ValueKey(item.shelfKey),
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
                maxLines: item.sourceName.isEmpty ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: FontUtils.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (item.sourceName.isNotEmpty)
                Text(
                  item.sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FontUtils.poppins(
                    fontSize: 10,
                    color: const Color(0xFF7f8c8d),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
