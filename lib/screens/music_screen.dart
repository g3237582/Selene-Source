import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/music_discovery.dart';
import '../models/music_track.dart';
import '../services/music_player_service.dart';
import '../services/music_service.dart';
import '../services/theme_service.dart';
import '../utils/font_utils.dart';
import '../utils/paged_list.dart';
import '../widgets/music_home_widgets.dart';
import '../widgets/music_track_tile.dart';
import '../widgets/paged_catalog_scroll.dart';
import 'music_player_screen.dart';
import 'music_playlist_screen.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _loadingMore = ValueNotifier(false);
  String _source = 'wy';
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

  bool get _inSearch => _searchController.text.trim().isNotEmpty;

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
        final boards = await MusicService.getBoards(source: _source);
        if (!mounted) return;
        setState(() {
          _boards = boards;
          _loadingHome = false;
        });
        return;
      }
      List<MusicTag> tags = _hotTags;
      try {
        tags = await MusicService.getSongListTags(source: _source);
      } catch (_) {}
      await _loadPlaylists(reset: true);
      if (!mounted) return;
      setState(() {
        _hotTags = tags;
        _loadingHome = false;
      });
    } catch (error) {
      if (_homeTab == 1) {
        try {
          final boards = await MusicService.getBoards(source: _source);
          if (!mounted) return;
          if (boards.isNotEmpty) {
            setState(() {
              _homeTab = 0;
              _boards = boards;
              _loadingHome = false;
              _error = null;
            });
            return;
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loadingHome = false;
      });
    }
  }

  Future<void> _loadPlaylists({required bool reset}) async {
    if (!reset && (_loadingHome || _loadingMore.value || !_playlistPage.hasMore)) {
      return;
    }
    if (reset) {
      _loadingMore.value = false;
    } else {
      _loadingMore.value = true;
    }
    try {
      final page = await MusicService.getSongLists(
        source: _source,
        tagId: _tagId,
        sortId: _sortId,
        page: reset ? 1 : _playlistPage.nextPage,
      );
      if (!mounted) return;
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
      _loadingMore.value = false;
    } catch (error) {
      if (!mounted) return;
      if (reset) {
        rethrow;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
      _loadingMore.value = false;
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

    if (reset) {
      setState(() {
        _searching = true;
        _searchPage = const PagedListState();
        _error = null;
      });
      _loadingMore.value = false;
    } else {
      _loadingMore.value = true;
    }

    try {
      final result = await MusicService.search(
        query: query,
        source: _source,
        page: reset ? 1 : _searchPage.nextPage,
      );
      if (!mounted) return;
      setState(() {
        _searchPage =
            (reset ? const PagedListState<MusicTrack>() : _searchPage).append(result);
        _searching = false;
      });
      _loadingMore.value = false;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _searching = false;
      });
      _loadingMore.value = false;
    }
  }

  void _changeSource(String source) {
    setState(() => _source = source);
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
          source: board.source.isNotEmpty ? board.source : _source,
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
          source: playlist.source.isNotEmpty ? playlist.source : _source,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(reset: true),
            onChanged: (value) {
              if (value.trim().isEmpty) {
                setState(() {
                  _searchPage = const PagedListState();
                  _error = null;
                });
                _loadingMore.value = false;
              }
            },
            decoration: InputDecoration(
              hintText: '搜索歌曲、歌手',
              hintStyle: FontUtils.poppins(color: muted, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: muted),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Color(0xFF27ae60)),
                onPressed: () => _search(reset: true),
              ),
              filled: true,
              fillColor: theme.isDarkMode
                  ? const Color(0xFF1e1e1e)
                  : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: FontUtils.poppins(color: textColor, fontSize: 14),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final entry in musicSourceLabels.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _source == entry.key,
                    onSelected: (_) => _changeSource(entry.key),
                    selectedColor: const Color(0xFF27ae60),
                    labelStyle: FontUtils.poppins(
                      fontSize: 12,
                      color: _source == entry.key ? Colors.white : textColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!_inSearch)
          MusicHomeTabBar(
            tab: _homeTab,
            onChanged: (tab) {
              setState(() => _homeTab = tab);
              _loadHome();
            },
          ),
        if (!_inSearch && _homeTab == 1) _buildSongListFilters(textColor),
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

  Widget _buildSongListFilters(Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final item in const [
                ('hot', '最热'),
                ('new', '最新'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.$2),
                    selected: _sortId == item.$1,
                    onSelected: (_) {
                      setState(() => _sortId = item.$1);
                      _loadHome();
                    },
                    selectedColor: const Color(0xFF27ae60),
                    labelStyle: FontUtils.poppins(
                      fontSize: 12,
                      color: _sortId == item.$1 ? Colors.white : textColor,
                    ),
                  ),
                ),
            ],
          ),
          if (_hotTags.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _hotTags.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ChoiceChip(
                      label: const Text('全部'),
                      selected: _tagId.isEmpty,
                      onSelected: (_) {
                        setState(() => _tagId = '');
                        _loadHome();
                      },
                      selectedColor: const Color(0xFF27ae60),
                      labelStyle: FontUtils.poppins(
                        fontSize: 12,
                        color: _tagId.isEmpty ? Colors.white : textColor,
                      ),
                    );
                  }
                  final tag = _hotTags[index - 1];
                  final selected = _tagId == tag.name;
                  return ChoiceChip(
                    label: Text(tag.name),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _tagId = tag.name);
                      _loadHome();
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
      ),
    );
  }

  Widget _buildBody(MusicPlayerService player, Color muted) {
    if (_inSearch) {
      return _buildSearch(player, muted);
    }
    if (_loadingHome) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: FontUtils.poppins(color: muted)));
    }
    if (_homeTab == 0) {
      return MusicBoardList(boards: _boards, onTap: _openBoard);
    }
    return MusicPlaylistGrid(
      key: ValueKey('playlists-$_source-$_sortId-$_tagId'),
      items: _playlistPage.items,
      hasMore: _playlistPage.hasMore,
      loadingMore: _loadingMore,
      onLoadMore: () => _loadPlaylists(reset: false),
      onTap: _openPlaylist,
    );
  }

  Widget _buildSearch(MusicPlayerService player, Color muted) {
    if (_searching && _searchPage.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _searchPage.items.isEmpty) {
      return Center(child: Text(_error!, style: FontUtils.poppins(color: muted)));
    }
    return PagedCatalogScroll(
      key: ValueKey('search-$_source-${_searchController.text.trim()}'),
      itemCount: _searchPage.items.length,
      hasMore: _searchPage.hasMore,
      loadingMoreListenable: _loadingMore,
      onLoadMore: () => _search(reset: false),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      empty: Center(
        child: Text('未找到相关歌曲', style: FontUtils.poppins(color: muted)),
      ),
      itemBuilder: (context, index) {
        final track = _searchPage.items[index];
        return ListenableBuilder(
          key: ValueKey(track.songId),
          listenable: player,
          builder: (context, _) {
            final playing = player.current?.songId == track.songId;
            return MusicTrackTile(
              track: track,
              playing: playing,
              paused: playing && !player.playing,
              onTap: () => MusicPlayerService.instance.playTrack(
                track,
                playlist: _searchPage.items,
              ),
              onOpenPlayer: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                );
              },
            );
          },
        );
      },
    );
  }
}
