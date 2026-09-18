import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/music_track.dart';
import '../services/music_player_service.dart';
import '../services/music_service.dart';
import '../services/theme_service.dart';
import '../utils/font_utils.dart';
import '../utils/paged_list.dart';
import '../widgets/authenticated_image.dart';
import 'music_player_screen.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _source = 'wy';
  PagedListState<MusicTrack> _page = const PagedListState();
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
      onLoadMore: () => _search(reset: false),
    );
  }

  Future<void> _search({required bool reset}) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    if (!reset && (_loading || _loadingMore || !_page.hasMore)) return;

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
      final result = await MusicService.search(
        query: query,
        source: _source,
        page: reset ? 1 : _page.nextPage,
      );
      if (!mounted) return;
      setState(() {
        _page = (reset ? const PagedListState<MusicTrack>() : _page).append(result);
        _loading = false;
        _loadingMore = false;
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

  Future<void> _play(MusicTrack track) async {
    await MusicPlayerService.instance.playTrack(track, playlist: _page.items);
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
                        onSelected: (_) {
                          setState(() => _source = entry.key);
                          if (_searchController.text.trim().isNotEmpty) {
                            _search(reset: true);
                          }
                        },
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
            if (player.errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  player.errorMessage,
                  style: FontUtils.poppins(color: const Color(0xFFe74c3c), fontSize: 12),
                ),
              ),
            Expanded(child: _buildList(player, textColor, muted)),
          ],
        );
      },
    );
  }

  Widget _buildList(MusicPlayerService player, Color textColor, Color muted) {
    if (_loading && _page.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _page.items.isEmpty) {
      return Center(child: Text(_error!, style: FontUtils.poppins(color: muted)));
    }
    if (_page.items.isEmpty) {
      return Center(
        child: Text('搜索歌曲后即可播放', style: FontUtils.poppins(color: muted)),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      itemCount: _page.items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _page.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final track = _page.items[index];
        final playing = player.current?.songId == track.songId;
        return ListTile(
          leading: SizedBox(
            width: 48,
            height: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: track.cover.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFF2c3e50),
                      child: Icon(Icons.music_note, color: Colors.white70),
                    )
                  : AuthenticatedImage(url: track.cover),
            ),
          ),
          title: Text(
            track.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FontUtils.poppins(
              fontWeight: playing ? FontWeight.w600 : FontWeight.w400,
              color: playing ? const Color(0xFF27ae60) : textColor,
            ),
          ),
          subtitle: Text(
            [
              track.artist,
              track.album,
              musicSourceLabels[track.source] ?? track.source,
            ].where((item) => item.isNotEmpty).join(' · '),
            maxLines: 1,
          ),
          trailing: IconButton(
            icon: Icon(
              playing && player.playing ? Icons.pause_circle : Icons.play_circle,
              color: const Color(0xFF27ae60),
            ),
            onPressed: () => _play(track),
          ),
          onTap: () => _play(track),
          onLongPress: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
            );
          },
        );
      },
    );
  }
}
