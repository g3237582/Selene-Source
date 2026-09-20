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
import '../widgets/search_pagination_bar.dart';
import 'music_player_screen.dart';
import 'music_playlist_screen.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _source = 'wy';
  int _homeTab = 0;
  PagedListState<MusicTrack> _searchPage = const PagedListState();
  List<MusicBoard> _boards = [];
  List<MusicPlaylist> _playlists = [];
  List<MusicTag> _hotTags = [];
  String _sortId = 'hot';
  String _tagId = '';
  int _playlistPage = 1;
  int _playlistPageCount = 1;
  bool _searching = false;
  bool _loadingHome = true;
  bool _loadingMore = false;
  String? _error;

  bool get _inSearch => _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHome() async {
    setState(() {
      _loadingHome = true;
      _error = null;
    });
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
      final page = await MusicService.getSongLists(
        source: _source,
        tagId: _tagId,
        sortId: _sortId,
        page: _playlistPage,
      );
      List<MusicTag> tags = _hotTags;
      try {
        tags = await MusicService.getSongListTags(source: _source);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _playlists = page.items;
        _hotTags = tags;
        _playlistPageCount = remotePageCount(page: page.page, hasMore: page.hasMore);
        _playlistPage = page.page;
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

  Future<void> _search({required bool reset}) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchPage = const PagedListState();
        _error = null;
      });
      return;
    }
    if (!reset && (_searching || _loadingMore || !_searchPage.hasMore)) return;

    setState(() {
      if (reset) {
        _searching = true;
        _searchPage = const PagedListState();
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

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
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _searching = false;
        _loadingMore = false;
      });
    }
  }

  void _changeSource(String source) {
    setState(() => _source = source);
    if (_inSearch) {
      _search(reset: true);
    } else {
      _playlistPage = 1;
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

    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
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
                  setState(() {
                    _homeTab = tab;
                    _playlistPage = 1;
                  });
                  _loadHome();
                },
              ),
            if (!_inSearch && _homeTab == 1) _buildSongListFilters(textColor),
            if (player.errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  player.errorMessage,
                  style: FontUtils.poppins(color: const Color(0xFFe74c3c), fontSize: 12),
                ),
              ),
            Expanded(child: _buildBody(player, muted)),
          ],
        );
      },
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
                      setState(() {
                        _sortId = item.$1;
                        _playlistPage = 1;
                      });
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
                        setState(() {
                          _tagId = '';
                          _playlistPage = 1;
                        });
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
                      setState(() {
                        _tagId = tag.name;
                        _playlistPage = 1;
                      });
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
    return Column(
      children: [
        Expanded(
          child: MusicPlaylistGrid(items: _playlists, onTap: _openPlaylist),
        ),
        if (_playlists.isNotEmpty)
          SearchPaginationBar(
            totalItems: _playlists.length,
            page: _playlistPage,
            pageCount: _playlistPageCount,
            summary: remoteSummaryText(
              pageItemCount: _playlists.length,
              page: _playlistPage,
              pageCount: _playlistPageCount,
            ),
            onPageChanged: (next) {
              setState(() => _playlistPage = next);
              _loadHome();
            },
          ),
      ],
    );
  }

  Widget _buildSearch(MusicPlayerService player, Color muted) {
    if (_searching && _searchPage.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _searchPage.items.isEmpty) {
      return Center(child: Text(_error!, style: FontUtils.poppins(color: muted)));
    }
    if (_searchPage.items.isEmpty) {
      return Center(
        child: Text('未找到相关歌曲', style: FontUtils.poppins(color: muted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      itemCount: _searchPage.items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _searchPage.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (index == _searchPage.items.length - 1 &&
            _searchPage.hasMore &&
            !_loadingMore &&
            !_searching) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _search(reset: false);
            }
          });
        }
        final track = _searchPage.items[index];
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
  }
}
