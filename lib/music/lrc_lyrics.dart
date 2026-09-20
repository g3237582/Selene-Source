import '../utils/html_text.dart';

/// Timed lyric line parsed from LRC, or a static fallback line.
class LyricLine {
  const LyricLine({required this.text, this.time});

  final String text;
  final Duration? time;
}

/// Parsed lyrics plus helpers for mapping playback position to a line.
class ParsedLyrics {
  const ParsedLyrics({required this.lines});

  final List<LyricLine> lines;

  bool get timed => lines.any((line) => line.time != null);

  static final _offsetPattern = RegExp(
    r'^\[offset:([+-]?\d+)\]$',
    caseSensitive: false,
  );
  static final _metadataPattern = RegExp(r'^\[[a-zA-Z]+:.*\]$');
  static final _timestampPattern = RegExp(
    r'\[(\d{1,3}):(\d{2})(?:[:.](\d{1,3}))?\]',
  );
  static final _wordTimestampPattern = RegExp(
    r'<\d{1,3}:\d{2}(?:[:.]\d{1,3})?>',
  );

  factory ParsedLyrics.parse(String raw) {
    final text = stripHtml(raw)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (text.isEmpty) {
      return const ParsedLyrics(lines: []);
    }

    var offset = Duration.zero;
    final sourceLines = text.split('\n');
    for (final source in sourceLines) {
      final match = _offsetPattern.firstMatch(source.trim());
      if (match != null) {
        offset = Duration(milliseconds: int.parse(match.group(1)!));
      }
    }

    final timed = <LyricLine>[];
    final untimed = <LyricLine>[];
    for (final source in sourceLines) {
      final line = source.trim();
      if (line.isEmpty || _offsetPattern.hasMatch(line)) {
        continue;
      }
      if (_metadataPattern.hasMatch(line)) {
        continue;
      }

      final stamps = _timestampPattern.allMatches(line).toList();
      if (stamps.isEmpty) {
        untimed.add(LyricLine(text: line));
        continue;
      }

      var cursor = 0;
      final times = <Duration>[];
      for (final stamp in stamps) {
        if (stamp.start != cursor) {
          break;
        }
        times.add(_stampDuration(stamp));
        cursor = stamp.end;
      }
      if (times.isEmpty) {
        untimed.add(LyricLine(text: line));
        continue;
      }

      final body = line
          .substring(cursor)
          .replaceAll(_wordTimestampPattern, '')
          .trim();
      if (body.isEmpty) {
        continue;
      }
      for (final time in times) {
        timed.add(LyricLine(text: body, time: _applyOffset(time, offset)));
      }
    }

    if (timed.isEmpty) {
      return ParsedLyrics(lines: untimed);
    }
    timed.sort((a, b) {
      final left = a.time ?? Duration.zero;
      final right = b.time ?? Duration.zero;
      return left.compareTo(right);
    });
    return ParsedLyrics(lines: timed);
  }

  /// Last timed line whose timestamp is <= [position], or -1 if none.
  int lineIndexAt(Duration position) {
    if (!timed) {
      return -1;
    }
    var low = 0;
    var high = lines.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final time = lines[mid].time;
      if (time == null) {
        low = mid + 1;
        continue;
      }
      if (time <= position) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }

  static Duration _stampDuration(RegExpMatch match) {
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: _fractionToMilliseconds(match.group(3)),
    );
  }

  static int _fractionToMilliseconds(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 0;
    }
    if (raw.length == 1) {
      return int.parse(raw) * 100;
    }
    if (raw.length == 2) {
      return int.parse(raw) * 10;
    }
    return int.parse(raw.substring(0, 3));
  }

  static Duration _applyOffset(Duration time, Duration offset) {
    final milliseconds = time.inMilliseconds + offset.inMilliseconds;
    return Duration(milliseconds: milliseconds < 0 ? 0 : milliseconds);
  }
}

/// Whether auto-follow should run after the user manually scrolled lyrics.
bool shouldResumeLyricFollow({
  required DateTime? lastManualScrollAt,
  required DateTime now,
  Duration idle = const Duration(seconds: 3),
}) {
  if (lastManualScrollAt == null) {
    return true;
  }
  return now.difference(lastManualScrollAt) >= idle;
}
