import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/manga.dart';
import '../services/manga_service.dart';
import '../services/theme_service.dart';
import '../search/all_source_search.dart';
import '../search/search_page_merge.dart';
import '../utils/font_utils.dart';
import '../utils/paged_list.dart';
import '../widgets/authenticated_image.dart';
import '../widgets/manga_library.dart';
import '../widgets/paged_catalog_scroll.dart';
import '../widgets/source_filter_bar.dart';
import 'manga_detail_screen.dart';

typedef _OpenManga = void Function(MangaItem item, {bool resumeIfPossible});

class MangaScreen extends StatefulWidget {
  const MangaScreen({super.key});

  @override
  State<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends State<MangaScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _loadingMore = ValueNotifier(false);
  List<MangaSource> _sources = [];
  String? _sourceId;
  Map<String, int> _allSourcePages = const {};
  PagedListState<MangaItem> _page = const PagedListState();
  List<MangaShelfItem> _shelf = [];
  List<MangaReadRecord> _history = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;
  int _discoverGeneration = 0;

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
      _loadLibrary(),
    ]);
    if (!mounted) return;
    await _reloadDiscover();
  }

  Future<void> _reloadDiscover() => _loadDiscover(reset: true);

  Future<void> _loadSources() async {
    try {
      final sources = await MangaService.getSources();
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
    final generation = reset ? ++_discoverGeneration : _discoverGeneration;
    final merge = SearchPageMerge<MangaItem>(reset: reset);
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
      late final PagedResult<MangaItem> result;
      if (query.isEmpty) {
        if (_sourceId == null) {
          final aggregated = await MangaService.recommendAll(
            sources: _sources,
            pages: reset ? const {} : _allSourcePages,
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
          _allSourcePages = aggregated.nextPages;
          if (aggregated.recommendErrorMessage != null &&
              aggregated.items.isEmpty &&
              !merge.replaced) {
            throw Exception(aggregated.recommendErrorMessage);
          }
          setState(() {
            _page = merge.complete(_page, aggregated);
            _loading = false;
            _error = null;
          });
          return;
        }
        result = await MangaService.recommend(
          sourceId: _sourceId!,
          page: reset ? 1 : _page.nextPage,
        );
      } else if (_sourceId == null) {
        final aggregated = await MangaService.searchAll(
          query: query,
          sources: _sources,
          pages: reset ? const {} : _allSourcePages,
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
        _allSourcePages = aggregated.nextPages;
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
        result = await MangaService.search(
          query: query,
          sourceId: _sourceId,
          page: reset ? 1 : _page.nextPage,
        );
      }
      if (!mounted || generation != _discoverGeneration) return;
      final page = result.items.isEmpty
          ? const PagedResult<MangaItem>(items: [], hasMore: false)
          : result;
      setState(() {
        _page = (reset ? const PagedListState<MangaItem>() : _page).append(page);
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

  Future<void> _loadLibrary() async {
    try {
      final results = await Future.wait([
        MangaService.getShelf(),
        MangaService.getHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _shelf = results[0] as List<MangaShelfItem>;
        _history = results[1] as List<MangaReadRecord>;
      });
    } catch (_) {}
  }

  void _openManga(MangaItem item, {bool resumeIfPossible = false}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => MangaDetailScreen(
              item: item,
              resumeIfPossible: resumeIfPossible,
            ),
          ),
        )
        .then((_) => _loadLibrary());
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
              _Chip(label: '发现', selected: _tab == 0, muted: muted, onTap: () => setState(() => _tab = 0)),
              const SizedBox(width: 8),
              _Chip(
                label: '书架',
                selected: _tab == 1,
                muted: muted,
                onTap: () {
                  setState(() => _tab = 1);
                  _loadLibrary();
                },
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
                hintText: '搜索漫画',
                hintStyle: FontUtils.poppins(color: muted, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: muted),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Color(0xFF27ae60)),
                  onPressed: () => _reloadDiscover(),
                ),
                filled: true,
                fillColor: theme.isDarkMode ? const Color(0xFF1e1e1e) : Colors.white,
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
                _allSourcePages = const {};
              });
              _reloadDiscover();
            },
          ),
        ],
        Expanded(
          child: _tab == 0
              ? _buildDiscover(muted)
              : MangaLibraryPane(shelf: _shelf, history: _history, onTap: _openManga),
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
    return _MangaGrid(
      key: ValueKey('manga-$_sourceId-$query'),
      items: _page.items,
      hasMore: _page.hasMore,
      loadingMore: _loadingMore,
      emptyLabel: query.isEmpty
          ? AllSourceSearch.homeEmptyLabel(
              kind: AllSourceHomeKind.manga,
              allSources: _sourceId == null,
            )
          : '未找到相关漫画',
      onLoadMore: () => _loadDiscover(reset: false),
      onTap: _openManga,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color muted;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF27ae60),
      labelStyle: FontUtils.poppins(color: selected ? Colors.white : muted),
    );
  }
}

class _MangaGrid extends StatelessWidget {
  final List<MangaItem> items;
  final bool hasMore;
  final ValueNotifier<bool> loadingMore;
  final String emptyLabel;
  final VoidCallback onLoadMore;
  final _OpenManga onTap;

  const _MangaGrid({
    super.key,
    required this.items,
    required this.hasMore,
    required this.loadingMore,
    this.emptyLabel = '暂无漫画',
    required this.onLoadMore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PagedCatalogScroll(
      itemCount: items.length,
      hasMore: hasMore,
      loadingMoreListenable: loadingMore,
      onLoadMore: onLoadMore,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      empty: Center(
        child: Text(
          emptyLabel,
          style: FontUtils.poppins(color: const Color(0xFF7f8c8d)),
        ),
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
                  child: AuthenticatedImage(url: item.cover),
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
