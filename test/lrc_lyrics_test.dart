import 'package:flutter_test/flutter_test.dart';
import 'package:selene/music/lrc_lyrics.dart';

void main() {
  group('ParsedLyrics.parse', () {
    test('empty input yields no lines and is untimed', () {
      final lyrics = ParsedLyrics.parse('');
      expect(lyrics.lines, isEmpty);
      expect(lyrics.timed, isFalse);
    });

    test('plain text without timestamps stays a static fallback', () {
      final lyrics = ParsedLyrics.parse('第一句\n第二句\n\n第三句');
      expect(lyrics.timed, isFalse);
      expect(lyrics.lines.map((line) => line.text), ['第一句', '第二句', '第三句']);
      expect(lyrics.lines.every((line) => line.time == null), isTrue);
    });

    test('parses standard LRC timestamps and skips metadata tags', () {
      const raw = '''
[ti:晴天]
[ar:周杰伦]
[offset:0]
[00:12.00]第一句
[00:15.50]第二句
[01:02.080]第三句
''';
      final lyrics = ParsedLyrics.parse(raw);
      expect(lyrics.timed, isTrue);
      expect(lyrics.lines, hasLength(3));
      expect(lyrics.lines[0].text, '第一句');
      expect(lyrics.lines[0].time, const Duration(seconds: 12));
      expect(lyrics.lines[1].text, '第二句');
      expect(lyrics.lines[1].time, const Duration(seconds: 15, milliseconds: 500));
      expect(lyrics.lines[2].text, '第三句');
      expect(lyrics.lines[2].time, const Duration(minutes: 1, seconds: 2, milliseconds: 80));
    });

    test('expands multiple leading timestamps on one line', () {
      final lyrics = ParsedLyrics.parse('[00:12.00][00:45.00]副歌');
      expect(lyrics.lines, hasLength(2));
      expect(lyrics.lines.map((line) => line.text), ['副歌', '副歌']);
      expect(lyrics.lines[0].time, const Duration(seconds: 12));
      expect(lyrics.lines[1].time, const Duration(seconds: 45));
    });

    test('applies offset to every timed line', () {
      final lyrics = ParsedLyrics.parse(
        '[offset:-500]\n[00:12.00]提前\n[00:20.00]下一句',
      );
      expect(
        lyrics.lines[0].time,
        const Duration(seconds: 11, milliseconds: 500),
      );
      expect(
        lyrics.lines[1].time,
        const Duration(seconds: 19, milliseconds: 500),
      );
    });

    test('accepts colon fractional seconds used by some Chinese players', () {
      final lyrics = ParsedLyrics.parse('[00:12:50]半秒');
      expect(lyrics.lines.single.time, const Duration(seconds: 12, milliseconds: 500));
    });

    test('strips word-level enhanced timestamps from the display text', () {
      final lyrics = ParsedLyrics.parse('[00:18.00]我<00:19.00>爱<00:19.50>你');
      expect(lyrics.lines.single.text, '我爱你');
      expect(lyrics.lines.single.time, const Duration(seconds: 18));
    });

    test('strips HTML then parses remaining LRC', () {
      final lyrics = ParsedLyrics.parse('<p>[00:10.00]你好&nbsp;世界</p>');
      expect(lyrics.lines.single.text, '你好 世界');
      expect(lyrics.lines.single.time, const Duration(seconds: 10));
    });

    test('drops blank timed lines and sorts by timestamp', () {
      final lyrics = ParsedLyrics.parse(
        '[00:20.00]后\n[00:10.00]\n[00:05.00]先',
      );
      expect(lyrics.lines.map((line) => line.text), ['先', '后']);
      expect(lyrics.lines[0].time, const Duration(seconds: 5));
    });

    test('mixed timed and untimed text keeps only timed lines', () {
      final lyrics = ParsedLyrics.parse('前言\n[00:08.00]正歌\n尾注');
      expect(lyrics.timed, isTrue);
      expect(lyrics.lines.map((line) => line.text), ['正歌']);
    });
  });

  group('ParsedLyrics.lineIndexAt', () {
    final lyrics = ParsedLyrics.parse(
      '[00:10.00]A\n[00:20.00]B\n[00:30.00]C',
    );

    test('returns -1 for untimed lyrics', () {
      expect(
        ParsedLyrics.parse('只有文字').lineIndexAt(const Duration(seconds: 5)),
        -1,
      );
    });

    test('returns -1 before the first timestamp', () {
      expect(lyrics.lineIndexAt(const Duration(seconds: 9)), -1);
    });

    test('selects the last line whose time has been reached', () {
      expect(lyrics.lineIndexAt(const Duration(seconds: 10)), 0);
      expect(lyrics.lineIndexAt(const Duration(seconds: 19, milliseconds: 999)), 0);
      expect(lyrics.lineIndexAt(const Duration(seconds: 20)), 1);
      expect(lyrics.lineIndexAt(const Duration(seconds: 30)), 2);
    });

    test('stays on the last line after the final timestamp', () {
      expect(lyrics.lineIndexAt(const Duration(minutes: 4)), 2);
    });

    test('seeking backwards maps to the earlier line', () {
      expect(lyrics.lineIndexAt(const Duration(seconds: 29)), 1);
      expect(lyrics.lineIndexAt(const Duration(seconds: 10)), 0);
    });
  });

  group('shouldResumeLyricFollow', () {
    final now = DateTime(2026, 9, 20, 13, 0, 0);

    test('follows immediately when the user has not scrolled', () {
      expect(
        shouldResumeLyricFollow(lastManualScrollAt: null, now: now),
        isTrue,
      );
    });

    test('stays paused during the idle window after a manual scroll', () {
      expect(
        shouldResumeLyricFollow(
          lastManualScrollAt: now.subtract(const Duration(seconds: 2)),
          now: now,
        ),
        isFalse,
      );
    });

    test('resumes after the idle window', () {
      expect(
        shouldResumeLyricFollow(
          lastManualScrollAt: now.subtract(const Duration(seconds: 3)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
