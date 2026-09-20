import 'dart:async';

import 'package:flutter/material.dart';

import '../music/music_now_playing.dart';
import '../screens/music_player_screen.dart';
import '../services/music_player_route_tracker.dart';
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
    @visibleForTesting this.debugPlaying,
    @visibleForTesting this.debugCanPlayPrevious,
    @visibleForTesting this.debugCanPlayNext,
  });

  final bool debugForceVisible;
  final double? debugProgress;
  final String? debugTitle;
  final String? debugCoverUrl;
  final bool? debugPlaying;
  final bool? debugCanPlayPrevious;
  final bool? debugCanPlayNext;

  @override
  State<MusicDynamicIsland> createState() => MusicDynamicIslandState();
}

class MusicDynamicIslandState extends State<MusicDynamicIsland>
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFF27ae60);
  static const _islandColor = Color(0xFF1e1e1e);
  static const _strokeWidth = 2.0;
  static const _expandDuration = Duration(milliseconds: 220);
  static const _autoCollapseDuration = Duration(seconds: 4);

  late final AnimationController _expandController;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  Timer? _collapseTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _expanded = false;

  bool get isExpanded => _expanded;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: _expandDuration,
    );
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
    _collapseTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _expandController.dispose();
    super.dispose();
  }

  void expand() {
    if (_expanded) {
      _restartCollapseTimer();
      return;
    }
    setState(() => _expanded = true);
    _expandController.forward();
    _restartCollapseTimer();
  }

  void collapse() {
    _collapseTimer?.cancel();
    if (!_expanded) {
      return;
    }
    setState(() => _expanded = false);
    _expandController.reverse();
  }

  void _toggleExpanded() {
    if (_expanded) {
      collapse();
    } else {
      expand();
    }
  }

  void _restartCollapseTimer() {
    _collapseTimer?.cancel();
    if (!_expanded) {
      return;
    }
    _collapseTimer = Timer(_autoCollapseDuration, collapse);
  }

  void _openPlayer() {
    if (widget.debugForceVisible) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MusicPlayerScreen(),
      ),
    );
  }

  void _playPrevious() {
    _restartCollapseTimer();
    if (widget.debugForceVisible) {
      return;
    }
    MusicPlayerService.instance.playPrevious();
  }

  void _togglePlay() {
    _restartCollapseTimer();
    if (widget.debugForceVisible) {
      return;
    }
    MusicPlayerService.instance.togglePlay();
  }

  void _playNext() {
    _restartCollapseTimer();
    if (widget.debugForceVisible) {
      return;
    }
    MusicPlayerService.instance.playNext();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.debugForceVisible) {
      return _buildVisibleIsland(
        progress: widget.debugProgress ?? 0.0,
        title: widget.debugTitle ?? '',
        coverUrl: widget.debugCoverUrl ?? '',
        playing: widget.debugPlaying ?? false,
        canPlayPrevious: widget.debugCanPlayPrevious ?? true,
        canPlayNext: widget.debugCanPlayNext ?? true,
      );
    }

    final player = MusicPlayerService.instance;
    final routeTracker = MusicPlayerRouteTracker.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([player, routeTracker]),
      builder: (context, _) {
        final track = player.current;
        if (!shouldShowMusicIsland(
          hasCurrentTrack: track != null,
          isOnFullPlayerRoute: routeTracker.isActive,
        )) {
          if (_expanded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                collapse();
              }
            });
          }
          return const SizedBox.shrink();
        }
        return _buildVisibleIsland(
          progress: musicIslandProgressFraction(
            position: _position,
            duration: _duration,
          ),
          title: track!.name,
          coverUrl: track.cover,
          playing: player.playing,
          canPlayPrevious: MusicNowPlaying.canSkipPreviousInQueue(
            player.queue,
            player.queueIndex,
          ),
          canPlayNext: MusicNowPlaying.canSkipNextInQueue(
            player.queue,
            player.queueIndex,
          ),
        );
      },
    );
  }

  Widget _buildVisibleIsland({
    required double progress,
    required String title,
    required String coverUrl,
    required bool playing,
    required bool canPlayPrevious,
    required bool canPlayNext,
  }) {
    return Stack(
      children: [
        if (_expanded)
          Positioned.fill(
            child: GestureDetector(
              key: const Key('music_dynamic_island_dismiss'),
              behavior: HitTestBehavior.translucent,
              onTap: collapse,
            ),
          ),
        Align(
          alignment: Alignment.topCenter,
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
              child: AnimatedBuilder(
                animation: _expandController,
                builder: (context, _) {
                  return _buildCapsule(
                    title: title,
                    coverUrl: coverUrl,
                    playing: playing,
                    canPlayPrevious: canPlayPrevious,
                    canPlayNext: canPlayNext,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCapsule({
    required String title,
    required String coverUrl,
    required bool playing,
    required bool canPlayPrevious,
    required bool canPlayNext,
  }) {
    return GestureDetector(
      key: const Key('music_dynamic_island'),
      onTap: _toggleExpanded,
      child: AnimatedContainer(
        duration: _expandDuration,
        curve: Curves.easeOutCubic,
        height: 36,
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
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
            GestureDetector(
              onTap: _openPlayer,
              child: _buildCover(coverUrl),
            ),
            if (title.trim().isNotEmpty) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _openPlayer,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _expanded ? 96 : 72),
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
              ),
            ],
            if (!_expanded) const SizedBox(width: 36),
            if (_expanded) ...[
              _buildTransportButton(
                key: const Key('music_island_prev'),
                icon: Icons.skip_previous,
                onPressed: canPlayPrevious ? _playPrevious : null,
              ),
              _buildTransportButton(
                key: const Key('music_island_play'),
                icon: playing ? Icons.pause : Icons.play_arrow,
                onPressed: _togglePlay,
              ),
              _buildTransportButton(
                key: const Key('music_island_next'),
                icon: Icons.skip_next,
                onPressed: canPlayNext ? _playNext : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransportButton({
    required Key key,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        key: key,
        padding: EdgeInsets.zero,
        iconSize: 20,
        color: Colors.white,
        disabledColor: Colors.white38,
        onPressed: onPressed,
        icon: Icon(icon),
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
