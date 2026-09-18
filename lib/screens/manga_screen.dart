import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/manga.dart';
import '../services/manga_service.dart';
import '../services/theme_service.dart';
import '../utils/font_utils.dart';
import '../utils/paged_list.dart';
import '../widgets/authenticated_image.dart';
import 'manga_detail_screen.dart';

class MangaScreen extends StatefulWidget {
  const MangaScreen({super.key});

  @override
  State<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends State<MangaScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MangaSource> _sources = [];
  String? _sourceId;
  PagedListState<MangaItem> _page = const PagedListState();
  List<MangaShelfItem> _shelf = [];
  List<MangaReadRecord> _history = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    handlePagedScroll(
      _scrollController,
      hasMore: _page.hasMore,
      isBusy: _loading || _loadingMore,
      onLoadMore: () => _loadDiscover(reset: false),
    );
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
    await _loadDiscover(reset: true);
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

  Future<void> _loadDiscover({required bool reset}) async {
    if (!reset && (_loading || _loadingMore || !_page.hasMore)) return;
    final query = _searchController.text.trim();
    if (query.isEmpty && _sourceId == null) {
      setState(() {
        _loading = false;
        _page = const PagedListState();
      });
      return;
    }

    setState(() {
      if (reset) {
        _loading = true;
        _page = const PagedListState();
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = query.isEmpty
          ? await MangaService.recommend(
              sourceId: _sourceId!,
              page: reset ? 1 : _page.nextPage,
            )
          : await MangaService.search(
              query: query,
              sourceId: _sourceId,
              page: reset ? 1 : _page.nextPage,
            );
      if (!mounted) return;
      setState(() {
        _page = (reset ? const PagedListState<MangaItem>() : _page).append(result);
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
      if (reset) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _onScroll();
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _loadingMore = false;
      });
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
              onSubmitted: (_) => _loadDiscover(reset: true),
              decoration: InputDecoration(
                hintText: '搜索漫画',
                hintStyle: FontUtils.poppins(color: muted, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: muted),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Color(0xFF27ae60)),
                  onPressed: () => _loadDiscover(reset: true),
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
                      _loadDiscover(reset: true);
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
    if (_loading && _page.items.isEmpty) {
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
    return _MangaGrid(
      items: _page.items,
      controller: _scrollController,
      loadingMore: _loadingMore,
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
  final ScrollController controller;
  final bool loadingMore;
  final ValueChanged<MangaItem> onTap;

  const _MangaGrid({
    required this.items,
    required this.controller,
    required this.loadingMore,
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
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
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
