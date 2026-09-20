import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../music/lrc_lyrics.dart';

/// Lyrics list that highlights and follows the current playback line.
class MusicLyricsView extends StatefulWidget {
  const MusicLyricsView({
    super.key,
    required this.lyric,
    required this.positionStream,
    this.initialPosition = Duration.zero,
    this.autoFollowResumeAfter = const Duration(seconds: 3),
  });

  final String lyric;
  final Stream<Duration> positionStream;
  final Duration initialPosition;
  final Duration autoFollowResumeAfter;

  @override
  State<MusicLyricsView> createState() => _MusicLyricsViewState();
}

class _MusicLyricsViewState extends State<MusicLyricsView> {
  static const _activeColor = Color(0xFF27ae60);
  static const _inactiveColor = Color(0xFF7f8c8d);

  late ParsedLyrics _lyrics;
  late Duration _position;
  StreamSubscription<Duration>? _positionSubscription;
  final ItemScrollController _itemScrollController = ItemScrollController();
  DateTime? _lastManualScrollAt;
  Timer? _resumeTimer;
  int _lastFollowedIndex = -2;
  bool _programmaticScroll = false;

  @override
  void initState() {
    super.initState();
    _lyrics = ParsedLyrics.parse(widget.lyric);
    _position = widget.initialPosition;
    _listen(widget.positionStream);
    WidgetsBinding.instance.addPostFrameCallback((_) => _followActiveLine());
  }

  @override
  void didUpdateWidget(MusicLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyric != widget.lyric) {
      _lyrics = ParsedLyrics.parse(widget.lyric);
      _position = widget.initialPosition;
      _lastManualScrollAt = null;
      _lastFollowedIndex = -2;
      WidgetsBinding.instance.addPostFrameCallback((_) => _followActiveLine());
    }
    if (oldWidget.positionStream != widget.positionStream) {
      _listen(widget.positionStream);
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _resumeTimer?.cancel();
    super.dispose();
  }

  void _listen(Stream<Duration> stream) {
    _positionSubscription?.cancel();
    _positionSubscription = stream.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() => _position = position);
      _followActiveLine();
    });
  }

  int get _activeIndex => _lyrics.lineIndexAt(_position);

  void _followActiveLine() {
    if (!_lyrics.timed || !mounted) {
      return;
    }
    if (!shouldResumeLyricFollow(
      lastManualScrollAt: _lastManualScrollAt,
      now: DateTime.now(),
      idle: widget.autoFollowResumeAfter,
    )) {
      return;
    }
    final index = _activeIndex;
    if (index < 0 ||
        index == _lastFollowedIndex ||
        !_itemScrollController.isAttached) {
      return;
    }
    _programmaticScroll = true;
    _lastFollowedIndex = index;
    _itemScrollController
        .scrollTo(
          index: index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: 0.4,
        )
        .whenComplete(() {
          _programmaticScroll = false;
        });
  }

  void _onUserScroll() {
    if (_programmaticScroll) {
      return;
    }
    _lastManualScrollAt = DateTime.now();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(widget.autoFollowResumeAfter, () {
      if (!mounted) {
        return;
      }
      _followActiveLine();
    });
  }

  TextStyle _lineStyle(bool active) {
    return TextStyle(
      fontSize: active ? 17 : 15,
      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
      height: 1.8,
      color: active ? _activeColor : _inactiveColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lyrics.lines.isEmpty) {
      return Center(
        child: Text(
          '暂无歌词',
          textAlign: TextAlign.center,
          style: _lineStyle(false),
        ),
      );
    }

    if (!_lyrics.timed) {
      return SingleChildScrollView(
        child: Column(
          children: [
            for (final line in _lyrics.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  line.text,
                  textAlign: TextAlign.center,
                  style: _lineStyle(false),
                ),
              ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _onUserScroll();
        }
        return false;
      },
      child: ScrollablePositionedList.builder(
        itemScrollController: _itemScrollController,
        itemCount: _lyrics.lines.length,
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 8),
        itemBuilder: (context, index) {
          final active = index == _activeIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _lyrics.lines[index].text,
              key: ValueKey('lyric-line-$index'),
              textAlign: TextAlign.center,
              style: _lineStyle(active),
            ),
          );
        },
      ),
    );
  }
}
