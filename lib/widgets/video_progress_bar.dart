import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../playback/player_progress.dart';

class VideoProgressBar extends StatefulWidget {
  final Player player;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDragUpdate;
  final ValueChanged<Duration>? onPositionUpdate;
  final Duration? dragPosition;
  final bool isSeekingViaSwipe;
  final bool live;
  final bool enableHoverThumb;

  const VideoProgressBar({
    super.key,
    required this.player,
    this.onDragStart,
    this.onDragEnd,
    this.onDragUpdate,
    this.onPositionUpdate,
    this.dragPosition,
    this.isSeekingViaSwipe = false,
    this.live = false,
    this.enableHoverThumb = false,
  });

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  static const _playedColor = Colors.red;
  static final _bufferedColor = Colors.red.withValues(alpha: 0.38);
  static final _trackColor = Colors.white.withValues(alpha: 0.3);

  bool _isDragging = false;
  bool _pointerMoved = false;
  double _dragValue = 0.0;
  bool _isHoveringThumb = false;
  Duration? _pendingSeek;
  DateTime? _pendingSeekAt;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _bufferSubscription;

  @override
  void initState() {
    super.initState();
    _positionSubscription = widget.player.stream.position.listen(_onPosition);
    _bufferSubscription = widget.player.stream.buffer.listen((_) {
      if (mounted && !_isDragging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _bufferSubscription?.cancel();
    super.dispose();
  }

  void _onPosition(Duration actual) {
    if (!mounted) {
      return;
    }
    var changed = false;
    if (_pendingSeek != null &&
        _pendingSeekAt != null &&
        PlayerProgress.seekSettled(
          actual: actual,
          target: _pendingSeek!,
          startedAt: _pendingSeekAt!,
        )) {
      _pendingSeek = null;
      _pendingSeekAt = null;
      changed = true;
    }
    if (!_isDragging || changed) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.player.state.duration;
    final position = widget.dragPosition ?? widget.player.state.position;
    final buffered = widget.player.state.buffer;
    final value = PlayerProgress.playValue(
      duration: duration,
      position: position,
      live: widget.live,
      dragging: _isDragging || widget.isSeekingViaSwipe,
      dragValue: _isDragging
          ? _dragValue
          : duration.inMilliseconds == 0
              ? 0.0
              : (position.inMilliseconds / duration.inMilliseconds),
      pendingSeek: _pendingSeek,
    );
    final bufferValue = PlayerProgress.bufferValue(
      duration: duration,
      buffered: buffered,
    );

    return MouseRegion(
      cursor: widget.live ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: widget.live
            ? null
            : (details) {
                _pointerMoved = true;
                _isDragging = true;
                widget.onDragStart?.call();
                _updateDragPosition(details.localPosition.dx, context);
              },
        onHorizontalDragUpdate: widget.live
            ? null
            : (details) {
                if (_isDragging) {
                  widget.onDragUpdate?.call();
                  _updateDragPosition(details.localPosition.dx, context);
                }
              },
        onHorizontalDragEnd: widget.live
            ? null
            : (details) async {
                if (_isDragging) {
                  await _commitSeek();
                }
              },
        onTapUp: widget.live
            ? null
            : (details) async {
                if (_pointerMoved || _isDragging) {
                  _pointerMoved = false;
                  return;
                }
                widget.onDragStart?.call();
                _updateDragPosition(details.localPosition.dx, context);
                await _commitSeek();
              },
        onTapDown: widget.live
            ? null
            : (_) {
                _pointerMoved = false;
              },
        child: Container(
          height: 24,
          color: Colors.transparent,
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final progressWidth = constraints.maxWidth;
                final progressValue = value.clamp(0.0, 1.0);
                final cachedWidth =
                    (bufferValue.clamp(0.0, 1.0) * progressWidth);
                final thumbPosition = (progressValue * progressWidth)
                    .clamp(8.0, progressWidth - 8.0);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 9,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: _trackColor,
                        ),
                      ),
                    ),
                    if (!widget.live)
                      Positioned(
                        left: 0,
                        top: 9,
                        child: Container(
                          width: cachedWidth,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: _bufferedColor,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      top: 9,
                      child: Container(
                        width: progressValue * progressWidth,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: _playedColor,
                        ),
                      ),
                    ),
                    if (!widget.live)
                      Positioned(
                        left: thumbPosition - 8,
                        top: 4,
                        child: MouseRegion(
                          onEnter: widget.enableHoverThumb
                              ? (_) => setState(() => _isHoveringThumb = true)
                              : null,
                          onExit: widget.enableHoverThumb
                              ? (_) => setState(() => _isHoveringThumb = false)
                              : null,
                          child: AnimatedScale(
                            scale: (_isHoveringThumb ||
                                    _isDragging ||
                                    widget.isSeekingViaSwipe)
                                ? 1.25
                                : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _playedColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _commitSeek() async {
    final duration = widget.player.state.duration;
    if (duration.inMilliseconds <= 0) {
      setState(() => _isDragging = false);
      widget.onDragEnd?.call();
      return;
    }

    final seekPosition = Duration(
      milliseconds: (_dragValue * duration.inMilliseconds).round(),
    );
    setState(() {
      _isDragging = false;
      _pointerMoved = false;
      _pendingSeek = seekPosition;
      _pendingSeekAt = DateTime.now();
    });

    try {
      await widget.player.seek(seekPosition);
    } catch (error) {
      debugPrint('VideoProgressBar: seek failed $error');
      if (mounted) {
        setState(() {
          _pendingSeek = null;
          _pendingSeekAt = null;
        });
      }
    }

    if (mounted) {
      widget.onDragEnd?.call();
    }
  }

  void _updateDragPosition(double dx, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }

    final width = box.size.width;
    final value = (dx / width).clamp(0.0, 1.0);
    setState(() {
      _dragValue = value;
    });

    final duration = widget.player.state.duration;
    final position = Duration(
      milliseconds: (value * duration.inMilliseconds).round(),
    );
    widget.onPositionUpdate?.call(position);
  }
}

/// Kept so existing PC controls can keep the previous type name.
typedef CustomVideoProgressBar = VideoProgressBar;
