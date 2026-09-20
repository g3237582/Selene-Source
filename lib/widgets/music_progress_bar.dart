import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../playback/player_progress.dart';

/// Playback scrubber for the music player. Seeking updates media_kit position,
/// which the lyrics view already follows.
class MusicProgressBar extends StatefulWidget {
  const MusicProgressBar({
    super.key,
    required this.player,
    this.loading = false,
  });

  final Player player;
  final bool loading;

  @override
  State<MusicProgressBar> createState() => _MusicProgressBarState();
}

class _MusicProgressBarState extends State<MusicProgressBar> {
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
    final canSeek = !widget.loading && duration.inMilliseconds > 0;

    return MusicProgressBarTrack(
      currentLabel: _format(shown),
      durationLabel: _format(duration),
      value: value,
      loading: widget.loading,
      onChanged: canSeek
          ? (next) {
              setState(() {
                _dragging = true;
                _dragValue = next;
              });
            }
          : null,
      onChangeEnd: canSeek
          ? (next) async {
              final target = _durationAt(next, duration);
              setState(() {
                _dragging = false;
                _dragValue = next;
              });
              await _seekTo(target);
            }
          : null,
    );
  }
}

/// Visual track used by [MusicProgressBar]. Loading replaces the slider with
/// an indeterminate indicator in the same slot so the page does not grow a
/// second progress area.
class MusicProgressBarTrack extends StatelessWidget {
  const MusicProgressBarTrack({
    super.key,
    required this.currentLabel,
    required this.durationLabel,
    required this.value,
    this.loading = false,
    this.onChanged,
    this.onChangeEnd,
  });

  static const Key loadingKey = Key('music-progress-loading');
  static const _accent = Color(0xFF27ae60);
  static const _labelColor = Color(0xFF7f8c8d);

  final String currentLabel;
  final String durationLabel;
  final double value;
  final bool loading;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            currentLabel,
            style: const TextStyle(fontSize: 12, color: _labelColor),
          ),
        ),
        Expanded(
          child: loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: LinearProgressIndicator(
                    key: loadingKey,
                    minHeight: 3,
                    color: _accent,
                    backgroundColor: Color(0x3327ae60),
                  ),
                )
              : SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _accent,
                    inactiveTrackColor: _accent.withValues(alpha: 0.2),
                    thumbColor: _accent,
                    overlayColor: _accent.withValues(alpha: 0.12),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: value.clamp(0.0, 1.0),
                    onChanged: onChanged,
                    onChangeEnd: onChangeEnd,
                  ),
                ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            durationLabel,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, color: _labelColor),
          ),
        ),
      ],
    );
  }
}
