import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/music_player_service.dart';
import 'authenticated_image.dart';

double musicIslandProgressFraction({
  required Duration position,
  required Duration duration,
}) {
  if (duration <= Duration.zero) return 0.0;
  final value = position.inMilliseconds / duration.inMilliseconds;
  if (value.isNaN) return 0.0;
  return value.clamp(0.0, 1.0);
}

bool shouldShowMusicIsland({
  required bool hasCurrentTrack,
  required bool isOnFullPlayerRoute,
}) {
  return hasCurrentTrack && !isOnFullPlayerRoute;
}

class MusicDynamicIsland extends StatefulWidget {
  const MusicDynamicIsland({
    super.key,
    @visibleForTesting this.debugForceVisible = false,
    @visibleForTesting this.debugProgress,
    @visibleForTesting this.debugTitle,
    @visibleForTesting this.debugCoverUrl,
  });

  final bool debugForceVisible;
  final double? debugProgress;
  final String? debugTitle;
  final String? debugCoverUrl;

  @override
  State<MusicDynamicIsland> createState() => _MusicDynamicIslandState();
}

class _MusicDynamicIslandState extends State<MusicDynamicIsland> {
  static const _accent = Color(0xFF27ae60);
  static const _islandColor = Color(0xFF1e1e1e);
  static const _strokeWidth = 2.0;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.debugForceVisible) {
      return;
    }
    final player = MusicPlayerService.instance;
    _position = player.player.state.position;
    _duration = player.player.state.duration;
    _positionSubscription = player.player.stream.position.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _durationSubscription = player.player.stream.duration.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.debugForceVisible) {
      return _buildVisibleIsland(
        progress: widget.debugProgress ?? 0.0,
        title: widget.debugTitle ?? '',
        coverUrl: widget.debugCoverUrl ?? '',
      );
    }

    final player = MusicPlayerService.instance;
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final track = player.current;
        if (!shouldShowMusicIsland(
          hasCurrentTrack: track != null,
          isOnFullPlayerRoute: false,
        )) {
          return const SizedBox.shrink();
        }
        return _buildVisibleIsland(
          progress: musicIslandProgressFraction(
            position: _position,
            duration: _duration,
          ),
          title: track!.name,
          coverUrl: track.cover,
        );
      },
    );
  }

  Widget _buildVisibleIsland({
    required double progress,
    required String title,
    required String coverUrl,
  }) {
    return Center(
      child: CustomPaint(
        key: const Key('music_dynamic_island_ring'),
        painter: _IslandProgressRingPainter(
          progress: progress,
          color: _accent,
          trackColor: Colors.white24,
          strokeWidth: _strokeWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(_strokeWidth),
          child: Container(
            key: const Key('music_dynamic_island'),
            height: 36,
            padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
            decoration: BoxDecoration(
              color: _islandColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCover(coverUrl),
                if (title.trim().isNotEmpty) ...[
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 72),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 28,
        height: 28,
        child: url.isEmpty
            ? const ColoredBox(
                color: Color(0xFF2c3e50),
                child: Icon(
                  Icons.music_note,
                  size: 16,
                  color: Colors.white70,
                ),
              )
            : AuthenticatedImage(url: url),
      ),
    );
  }
}

class _IslandProgressRingPainter extends CustomPainter {
  _IslandProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(size.height / 2),
    );
    final path = Path()..addRRect(rrect);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, trackPaint);

    if (progress <= 0) {
      return;
    }
    final metric = path.computeMetrics().first;
    final extract = metric.extractPath(
      0,
      metric.length * progress.clamp(0.0, 1.0),
    );
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(extract, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _IslandProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
