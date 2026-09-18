import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/music_track.dart';
import '../services/music_player_service.dart';
import '../services/music_service.dart';
import '../services/theme_service.dart';
import '../utils/font_utils.dart';
import '../widgets/authenticated_image.dart';
import 'music_player_screen.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _source = 'wy';
  List<MusicTrack> _tracks = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tracks = await MusicService.search(query: query, source: _source);
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
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

  Future<void> _play(MusicTrack track) async {
    await MusicPlayerService.instance.playTrack(track, playlist: _tracks);
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
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: '搜索歌曲、歌手',
                  hintStyle: FontUtils.poppins(color: muted, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: muted),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Color(0xFF27ae60)),
                    onPressed: _search,
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
                            _search();
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: FontUtils.poppins(color: muted)))
                      : _tracks.isEmpty
                          ? Center(
                              child: Text(
                                '搜索歌曲后即可播放',
                                style: FontUtils.poppins(color: muted),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                              itemCount: _tracks.length,
                              itemBuilder: (context, index) {
                                final track = _tracks[index];
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
                                              child: Icon(Icons.music_note,
                                                  color: Colors.white70),
                                            )
                                          : AuthenticatedImage(url: track.cover),
                                    ),
                                  ),
                                  title: Text(
                                    track.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: FontUtils.poppins(
                                      fontWeight: playing
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: playing
                                          ? const Color(0xFF27ae60)
                                          : textColor,
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
                                      playing && player.playing
                                          ? Icons.pause_circle
                                          : Icons.play_circle,
                                      color: const Color(0xFF27ae60),
                                    ),
                                    onPressed: () => _play(track),
                                  ),
                                  onTap: () => _play(track),
                                  onLongPress: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const MusicPlayerScreen(),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}
