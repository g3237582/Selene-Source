import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../playback/player_progress.dart';

/// Playback scrubber for the music player. Seeking updates media_kit position,
/// which the lyrics view already follows.
class MusicProgressBar extends StatefulWidget {
  const MusicProgressBar({super.key, required this.player});

  final Player player;

  @override
  State<MusicProgressBar> createState() => _MusicProgressBarState();
}

class _MusicProgressBarState extends State<MusicProgressBar> {
  static const _accent = Color(0xFF27ae60);
  static const _labelColor = Color(0xFF7f8c8d);

  bool _dragging = false;
  double _dragValue = 0;
  Duration? _pendingSeek;
  DateTime? _pendingSeekAt;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _positionSubscription = widget.player.stream.position.listen(_onPosition);
    _durationSubscription = widget.player.stream.duration.listen((_) {
      if (mounted && !_dragging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
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
    if (!_dragging || changed) {
      setState(() {});
    }
  }

  String _format(Duration duration) {
    final clamped = duration.isNegative ? Duration.zero : duration;
    final minutes = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = clamped.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Duration _durationAt(double value, Duration duration) {
    return Duration(
      milliseconds: (duration.inMilliseconds * value.clamp(0.0, 1.0)).round(),
    );
  }

  Future<void> _seekTo(Duration target) async {
    _pendingSeek = target;
    _pendingSeekAt = DateTime.now();
    await widget.player.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.player.state.duration;
    final position = widget.player.state.position;
    final value = PlayerProgress.playValue(
      duration: duration,
      position: position,
      live: false,
      dragging: _dragging,
      dragValue: _dragValue,
      pendingSeek: _pendingSeek,
    );
    final shown = _dragging || _pendingSeek != null
        ? _durationAt(value, duration)
        : position;

    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            _format(shown),
            style: const TextStyle(fontSize: 12, color: _labelColor),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _accent,
              inactiveTrackColor: _accent.withValues(alpha: 0.2),
              thumbColor: _accent,
              overlayColor: _accent.withValues(alpha: 0.12),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              onChanged: duration.inMilliseconds <= 0
                  ? null
                  : (next) {
                      setState(() {
                        _dragging = true;
                        _dragValue = next;
                      });
                    },
              onChangeEnd: duration.inMilliseconds <= 0
                  ? null
                  : (next) async {
                      final target = _durationAt(next, duration);
                      setState(() {
                        _dragging = false;
                        _dragValue = next;
                      });
                      await _seekTo(target);
                    },
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            _format(duration),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, color: _labelColor),
          ),
        ),
      ],
    );
  }
}
