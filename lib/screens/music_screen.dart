import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/music_discovery.dart';
import '../models/music_track.dart';
import '../services/music_player_service.dart';
import '../services/music_service.dart';
import '../search/all_source_search.dart';
import '../search/search_page_merge.dart';
import '../services/theme_service.dart';
import '../utils/font_utils.dart';
import '../utils/paged_list.dart';
import '../widgets/music_home_widgets.dart';
import '../widgets/music_search_list.dart';
import '../widgets/source_filter_bar.dart';
import 'music_playlist_screen.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _loadingMore = ValueNotifier(false);
  String? _source;
  String _browseSource = 'wy';
  Map<String, int> _allSourcePages = const {};
  Map<String, int> _allSourcePlaylistPages = const {};
  int _homeTab = 0;
  PagedListState<MusicTrack> _searchPage = const PagedListState();
  PagedListState<MusicPlaylist> _playlistPage = const PagedListState();
  List<MusicBoard> _boards = [];
  List<MusicTag> _hotTags = [];
  String _sortId = 'hot';
  String _tagId = '';
  bool _searching = false;
  bool _loadingHome = true;
  String? _error;
  int _playlistGeneration = 0;
  int _searchGeneration = 0;

  bool get _inSearch => _searchController.text.trim().isNotEmpty;

  bool get _allSources => _source == null;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  @override
  void dispose() {
    _loadingMore.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHome() async {
    setState(() {
      _loadingHome = true;
      _error = null;
      if (_homeTab == 1) {
        _playlistPage = const PagedListState();
      }
    });
    _loadingMore.value = false;
    try {
      if (_homeTab == 0) {
        await _loadBoards();
        return;
      }
      List<MusicTag> tags = _hotTags;
      if (!_allSources) {
        try {
          tags = await MusicService.getSongListTags(source: _browseSource);
        } catch (_) {}
      } else {
        tags = const [];
      }
      await _loadPlaylists(reset: true);
      if (!mounted) return;
      setState(() {
        _hotTags = tags;
        _loadingHome = false;
      });
    } catch (error) {
      if (_homeTab == 1) {
        try {
          await _loadBoards(asFallback: true);
          return;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loadingHome = false;
      });
    }
  }

  Future<void> _loadBoards({bool asFallback = false}) async {
    if (_allSources) {
      final merge = SearchPageMerge<MusicBoard>(reset: true);
      var state = const PagedListState<MusicBoard>();
      final aggregated = await MusicService.getBoardsAll(
        onPartial: (partial) {
          if (!mounted) {
            return;
          }
          state = merge.absorb(state, partial.items);
          setState(() {
            _boards = state.items;
            if (asFallback) {
              _homeTab = 0;
            }
            _loadingHome = false;
            _error = null;
          });
        },
      );
      if (!mounted) return;
      if (aggregated.recommendErrorMessage != null &&
          aggregated.items.isEmpty &&
          !merge.replaced) {
        throw Exception(aggregated.recommendErrorMessage);
      }
      if (asFallback && aggregated.items.isEmpty && !merge.replaced) {
        throw Exception(aggregated.recommendErrorMessage ?? '暂无排行榜');
      }
      setState(() {
        if (!merge.replaced) {
          _boards = aggregated.items;
        }
        if (asFallback) {
          _homeTab = 0;
        }
        _loadingHome = false;
        _error = null;
      });
      return;
    }
    final boards = await MusicService.getBoards(source: _browseSource);
    if (!mounted) return;
    if (asFallback && boards.isEmpty) {
      throw Exception('当前音源暂无排行榜数据');
    }
    setState(() {
      _boards = boards;
      if (asFallback) {
        _homeTab = 0;
      }
      _loadingHome = false;
      _error = null;
    });
  }

  Future<void> _loadPlaylists({required bool reset}) async {
    if (!reset && (_loadingHome || _loadingMore.value || !_playlistPage.hasMore)) {
      return;
    }
    final generation = reset ? ++_playlistGeneration : _playlistGeneration;
    if (reset) {
      _loadingMore.value = false;
    } else {
      _loadingMore.value = true;
    }
    try {
      if (_allSources) {
        final merge = SearchPageMerge<MusicPlaylist>(reset: reset);
        final aggregated = await MusicService.getSongListsAll(
          pages: reset ? const {} : _allSourcePlaylistPages,
          sortId: _sortId,
          onPartial: (partial) {
            if (!mounted || generation != _playlistGeneration) {
              return;
            }
            setState(() {
              _playlistPage = merge.absorb(_playlistPage, partial.items);
              if (reset) {
                _loadingHome = false;
              }
            });
          },
        );
        if (!mounted || generation != _playlistGeneration) return;
        _allSourcePlaylistPages = aggregated.nextPages;
        if (aggregated.recommendErrorMessage != null &&
            aggregated.items.isEmpty &&
            !merge.replaced) {
          throw Exception(aggregated.recommendErrorMessage);
        }
        setState(() {
          _playlistPage = merge.complete(_playlistPage, aggregated);
          if (reset) {
            _loadingHome = false;
          }
        });
        return;
      }
      final page = await MusicService.getSongLists(
        source: _browseSource,
        tagId: _tagId,
        sortId: _sortId,
        page: reset ? 1 : _playlistPage.nextPage,
      );
      if (!mounted || generation != _playlistGeneration) return;
      final result = PagedResult(
        items: page.items,
        hasMore: page.hasMore && page.items.isNotEmpty,
      );
      setState(() {
        _playlistPage =
            (reset ? const PagedListState<MusicPlaylist>() : _playlistPage)
                .append(result);
        if (reset) {
          _loadingHome = false;
        }
      });
    } catch (error) {
      if (!mounted || generation != _playlistGeneration) return;
      if (reset) {
        rethrow;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (generation == _playlistGeneration) {
        _loadingMore.value = false;
      }
    }
  }

  Future<void> _search({required bool reset}) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchPage = const PagedListState();
        _error = null;
      });
      _loadingMore.value = false;
      return;
    }
    if (!reset && (_searching || _loadingMore.value || !_searchPage.hasMore)) {
      return;
    }

    final generation = reset ? ++_searchGeneration : _searchGeneration;
    final merge = SearchPageMerge<MusicTrack>(reset: reset);
    if (reset) {
      setState(() {
        _searching = true;
        _error = null;
      });
    }
    _loadingMore.value = true;

    try {
      late final PagedResult<MusicTrack> result;
      if (_source == null) {
        final aggregated = await MusicService.searchAll(
          query: query,
          pages: reset ? const {} : _allSourcePages,
          onPartial: (partial) {
            if (!mounted || generation != _searchGeneration) {
              return;
            }
            setState(() {
              _searchPage = merge.absorb(_searchPage, partial.items);
              _searching = false;
              _error = null;
            });
          },
        );
        if (!mounted || generation != _searchGeneration) return;
        _allSourcePages = aggregated.nextPages;
        if (aggregated.errorMessage != null &&
            aggregated.items.isEmpty &&
            !merge.replaced) {
          throw Exception(aggregated.errorMessage);
        }
        setState(() {
          _searchPage = merge.complete(_searchPage, aggregated);
          _searching = false;
        });
        return;
      } else {
        result = await MusicService.search(
          query: query,
          source: _source!,
          page: reset ? 1 : _searchPage.nextPage,
        );
      }
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchPage =
            (reset ? const PagedListState<MusicTrack>() : _searchPage).append(result);
        _searching = false;
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _searching = false;
      });
    } finally {
      if (generation == _searchGeneration) {
        _loadingMore.value = false;
      }
    }
  }

  void _changeSource(String? source) {
    setState(() {
      _source = source;
      if (source != null) {
        _browseSource = source;
      } else {
        _tagId = '';
      }
      _allSourcePages = const {};
      _allSourcePlaylistPages = const {};
    });
    if (_inSearch) {
      _search(reset: true);
    } else {
      _loadHome();
    }
  }

  void _openBoard(MusicBoard board) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MusicPlaylistScreen(
          title: board.name,
          source: board.source.isNotEmpty ? board.source : _browseSource,
          id: board.id,
          kind: MusicPlaylistKind.board,
        ),
      ),
    );
  }

  void _openPlaylist(MusicPlaylist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MusicPlaylistScreen(
          title: playlist.name,
          source: playlist.source.isNotEmpty ? playlist.source : _browseSource,
          id: playlist.id,
          kind: MusicPlaylistKind.songlist,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final player = MusicPlayerService.instance;
    final textColor =
        theme.isDarkMode ? Colors.white : const Color(0xFF2c3e50);
    final muted = theme.isDarkMode
        ? const Color(0xFFb0b0b0)
        : const Color(0xFF7f8c8d);

    return Column(
      children: [
        MusicSearchField(
          controller: _searchController,
          muted: muted,
          textColor: textColor,
          fillColor: theme.isDarkMode ? const Color(0xFF1e1e1e) : Colors.white,
          onSubmitted: () => _search(reset: true),
          onChanged: (value) {
            if (value.trim().isEmpty) {
              setState(() {
                _searchPage = const PagedListState();
                _error = null;
              });
              _loadingMore.value = false;
            }
          },
        ),
        SourceFilterBar(
          sources: [
            for (final entry in musicSourceLabels.entries)
              SourceFilterOption(id: entry.key, name: entry.value),
          ],
          selectedId: _source,
          textColor: textColor,
          onSelected: _changeSource,
        ),
        if (!_inSearch)
          MusicHomeTabBar(
            tab: _homeTab,
            onChanged: (tab) {
              setState(() => _homeTab = tab);
              _loadHome();
            },
          ),
        if (!_inSearch && _homeTab == 1)
          MusicSongListFilters(
            sortId: _sortId,
            tagId: _tagId,
            tags: _hotTags,
            showTags: !_allSources,
            textColor: textColor,
            onSortChanged: (sortId) {
              setState(() => _sortId = sortId);
              _loadHome();
            },
            onTagChanged: (tagId) {
              setState(() => _tagId = tagId);
              _loadHome();
            },
          ),
        ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            if (player.errorMessage.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                player.errorMessage,
                style: FontUtils.poppins(color: const Color(0xFFe74c3c), fontSize: 12),
              ),
            );
          },
        ),
        Expanded(child: _buildBody(player, muted)),
      ],
    );
  }

  Widget _buildBody(MusicPlayerService player, Color muted) {
    if (_inSearch) {
      return MusicSearchList(
        items: _searchPage.items,
        hasMore: _searchPage.hasMore,
        loadingMore: _loadingMore,
        searching: _searching,
        error: _error,
        sourceKey: 'search-$_source-${_searchController.text.trim()}',
        muted: muted,
        onLoadMore: () => _search(reset: false),
      );
    }
    if (_loadingHome) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: FontUtils.poppins(color: muted)));
    }
    if (_homeTab == 0) {
      return MusicBoardList(
        boards: _boards,
        showSource: _allSources,
        emptyLabel: AllSourceSearch.homeEmptyLabel(
          kind: AllSourceHomeKind.musicBoard,
          allSources: _allSources,
        ),
        onTap: _openBoard,
      );
    }
    return MusicPlaylistGrid(
      key: ValueKey('playlists-${_source ?? 'all'}-$_sortId-$_tagId'),
      items: _playlistPage.items,
      hasMore: _playlistPage.hasMore,
      loadingMore: _loadingMore,
      showSource: _allSources,
      emptyLabel: AllSourceSearch.homeEmptyLabel(
        kind: AllSourceHomeKind.musicPlaylist,
        allSources: _allSources,
      ),
      onLoadMore: () => _loadPlaylists(reset: false),
      onTap: _openPlaylist,
    );
  }
}
