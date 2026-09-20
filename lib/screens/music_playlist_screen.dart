import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/music_discovery.dart';
import '../models/music_track.dart';
import '../services/music_player_service.dart';
import '../services/music_service.dart';
import '../services/theme_service.dart';
import '../utils/font_utils.dart';
import '../widgets/music_track_tile.dart';
import 'music_player_screen.dart';

class MusicPlaylistScreen extends StatefulWidget {
  final String title;
  final String source;
  final String id;
  final MusicPlaylistKind kind;

  const MusicPlaylistScreen({
    super.key,
    required this.title,
    required this.source,
    required this.id,
    required this.kind,
  });

  @override
  State<MusicPlaylistScreen> createState() => _MusicPlaylistScreenState();
}

class _MusicPlaylistScreenState extends State<MusicPlaylistScreen> {
  List<MusicTrack> _songs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = widget.kind == MusicPlaylistKind.board
          ? await MusicService.getBoardSongsWithFallback(
              source: widget.source,
              boardId: widget.id,
              title: widget.title,
            )
          : await MusicService.getSongListDetail(
              source: widget.source,
              id: widget.id,
            );
      if (!mounted) return;
      setState(() {
        _songs = page.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _playAt(int index) async {
    await MusicPlayerService.instance.playPlaylist(_songs, index: index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final player = MusicPlayerService.instance;
    final muted = theme.isDarkMode
        ? const Color(0xFFb0b0b0)
        : const Color(0xFF7f8c8d);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: FontUtils.poppins()),
        actions: [
          TextButton.icon(
            onPressed: _songs.isEmpty ? null : () => _playAt(0),
            icon: const Icon(Icons.play_arrow, color: Color(0xFF27ae60)),
            label: Text(
              '播放全部',
              style: FontUtils.poppins(color: const Color(0xFF27ae60)),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: player,
        builder: (context, _) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return Center(child: Text(_error!, style: FontUtils.poppins(color: muted)));
          }
          if (_songs.isEmpty) {
            return Center(
              child: Text('暂无歌曲', style: FontUtils.poppins(color: muted)),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_songs.length} 首歌曲',
                    style: FontUtils.poppins(fontSize: 13, color: muted),
                  ),
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
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final track = _songs[index];
                    final playing = player.current?.songId == track.songId;
                    return MusicTrackTile(
                      track: track,
                      index: index,
                      playing: playing,
                      paused: playing && !player.playing,
                      onTap: () => _playAt(index),
                      onOpenPlayer: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
