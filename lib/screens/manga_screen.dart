import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/manga.dart';
import '../services/manga_service.dart';
import '../services/theme_service.dart';
import '../search/search_list_paging.dart';
import '../utils/font_utils.dart';
import '../utils/paged_list.dart';
import '../widgets/authenticated_image.dart';
import '../widgets/search_pagination_bar.dart';
import 'manga_detail_screen.dart';

class MangaScreen extends StatefulWidget {
  const MangaScreen({super.key});

  @override
  State<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends State<MangaScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<MangaSource> _sources = [];
  String? _sourceId;
  List<MangaItem> _loadedItems = [];
  List<MangaItem> _items = [];
  int _page = 1;
  int _remoteNextPage = 1;
  bool _remoteHasMore = true;
  List<MangaShelfItem> _shelf = [];
  List<MangaReadRecord> _history = [];
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
      _loadLibrary(),
    ]);
    if (!mounted) return;
    await _reloadDiscover();
  }

  Future<void> _reloadDiscover() {
    _loadedItems = [];
    _remoteNextPage = 1;
    _remoteHasMore = true;
    return _loadDiscover(page: 1);
  }

  Future<void> _loadSources() async {
    try {
      final sources = await MangaService.getSources();
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
    if (_loading && _items.isNotEmpty && page == _page) return;
    final query = _searchController.text.trim();
    if (query.isEmpty && _sourceId == null) {
      setState(() {
        _loading = false;
        _loadedItems = [];
        _items = [];
        _page = 1;
        _remoteNextPage = 1;
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
      while (_loadedItems.length < needed && _remoteHasMore) {
        final result = query.isEmpty
            ? await MangaService.recommend(
                sourceId: _sourceId!,
                page: _remoteNextPage,
              )
            : await MangaService.search(
                query: query,
                sourceId: _sourceId,
                page: _remoteNextPage,
              );
        if (!mounted) return;
        if (result.items.isEmpty) {
          _remoteHasMore = false;
          break;
        }
        _loadedItems = [..._loadedItems, ...result.items];
        _remoteNextPage += 1;
        _remoteHasMore = result.hasMore;
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

  void _openManga(MangaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MangaDetailScreen(item: item)),
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
              _Chip(label: '发现', selected: _tab == 0, muted: muted, onTap: () => setState(() => _tab = 0)),
              const SizedBox(width: 8),
              _Chip(label: '书架', selected: _tab == 1, muted: muted, onTap: () => setState(() => _tab = 1)),
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
          if (_sources.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _sources.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final source = _sources[index];
                  final selected = source.id == _sourceId;
                  return ChoiceChip(
                    label: Text(source.name),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _sourceId = source.id);
                      _reloadDiscover();
                    },
                    selectedColor: const Color(0xFF27ae60),
                    labelStyle: FontUtils.poppins(
                      fontSize: 12,
                      color: selected ? Colors.white : textColor,
                    ),
                  );
                },
              ),
            ),
        ],
        Expanded(
          child: _tab == 0
              ? _buildDiscover(muted)
              : _MangaLibrary(shelf: _shelf, history: _history, onTap: _openManga),
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
              : _MangaGrid(
                  items: _items,
                  onTap: _openManga,
                ),
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
  final ValueChanged<MangaItem> onTap;

  const _MangaGrid({
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text('暂无漫画', style: FontUtils.poppins(color: const Color(0xFF7f8c8d))),
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
                  child: AuthenticatedImage(url: item.cover),
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

class _MangaLibrary extends StatelessWidget {
  final List<MangaShelfItem> shelf;
  final List<MangaReadRecord> history;
  final ValueChanged<MangaItem> onTap;

  const _MangaLibrary({
    required this.shelf,
    required this.history,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text('书架', style: FontUtils.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
        if (shelf.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Text('书架是空的', style: FontUtils.poppins(color: const Color(0xFF7f8c8d))),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = shelf[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 48,
                      height: 64,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AuthenticatedImage(url: item.cover),
                      ),
                    ),
                    title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      item.lastChapterName.isEmpty
                          ? item.sourceName
                          : item.lastChapterName,
                      maxLines: 1,
                    ),
                    onTap: () => onTap(item.toItem()),
                  );
                },
                childCount: shelf.length,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text('阅读历史', style: FontUtils.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
        if (history.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
              child: Text('暂无历史', style: FontUtils.poppins(color: const Color(0xFF7f8c8d))),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = history[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.chapterName, maxLines: 1),
                    onTap: () => onTap(item.toItem()),
                  );
                },
                childCount: history.length,
              ),
            ),
          ),
      ],
    );
  }
}
