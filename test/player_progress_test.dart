import 'package:flutter_test/flutter_test.dart';
import 'package:selene/playback/player_progress.dart';
import 'package:selene/playback/player_stream_cache.dart';

void main() {
  group('PlayerProgress.playValue', () {
    test('returns 0 when duration is zero', () {
      expect(
        PlayerProgress.playValue(
          duration: Duration.zero,
          position: const Duration(seconds: 10),
          live: false,
          dragging: false,
          dragValue: 0.4,
        ),
        0.0,
      );
    });

    test('returns 1 for live playback', () {
      expect(
        PlayerProgress.playValue(
          duration: const Duration(seconds: 100),
          position: const Duration(seconds: 12),
          live: true,
          dragging: false,
          dragValue: 0.2,
        ),
        1.0,
      );
    });

    test('uses drag value while dragging', () {
      expect(
        PlayerProgress.playValue(
          duration: const Duration(seconds: 100),
          position: const Duration(seconds: 10),
          live: false,
          dragging: true,
          dragValue: 0.73,
        ),
        closeTo(0.73, 1e-9),
      );
    });

    test('keeps pending seek instead of stale position', () {
      expect(
        PlayerProgress.playValue(
          duration: const Duration(seconds: 100),
          position: const Duration(seconds: 10),
          live: false,
          dragging: false,
          dragValue: 0.0,
          pendingSeek: const Duration(seconds: 80),
        ),
        closeTo(0.8, 1e-9),
      );
    });

    test('follows actual position after pending seek is cleared', () {
      expect(
        PlayerProgress.playValue(
          duration: const Duration(seconds: 100),
          position: const Duration(seconds: 81),
          live: false,
          dragging: false,
          dragValue: 0.0,
        ),
        closeTo(0.81, 1e-9),
      );
    });
  });

  group('PlayerProgress.bufferValue', () {
    test('clamps buffered duration to the timeline', () {
      expect(
        PlayerProgress.bufferValue(
          duration: const Duration(seconds: 50),
          buffered: const Duration(seconds: 80),
        ),
        1.0,
      );
    });

    test('returns the buffered ratio', () {
      expect(
        PlayerProgress.bufferValue(
          duration: const Duration(seconds: 100),
          buffered: const Duration(seconds: 35),
        ),
        closeTo(0.35, 1e-9),
      );
    });
  });

  group('PlayerProgress.seekSettled', () {
    final startedAt = DateTime(2026, 9, 17, 2, 0, 0);

    test('is false while the player is still far from the target', () {
      expect(
        PlayerProgress.seekSettled(
          actual: const Duration(seconds: 10),
          target: const Duration(seconds: 80),
          startedAt: startedAt,
          now: startedAt.add(const Duration(milliseconds: 100)),
        ),
        isFalse,
      );
    });

    test('is true when the player catches the target', () {
      expect(
        PlayerProgress.seekSettled(
          actual: const Duration(milliseconds: 80200),
          target: const Duration(seconds: 80),
          startedAt: startedAt,
          now: startedAt.add(const Duration(milliseconds: 200)),
        ),
        isTrue,
      );
    });

    test('releases the pending seek after timeout', () {
      expect(
        PlayerProgress.seekSettled(
          actual: const Duration(seconds: 10),
          target: const Duration(seconds: 80),
          startedAt: startedAt,
          now: startedAt.add(const Duration(seconds: 3)),
        ),
        isTrue,
      );
    });
  });

  group('PlayerStreamCache', () {
    test('uses a larger demuxer buffer for VOD than live', () {
      expect(
        PlayerStreamCache.configuration(live: false).bufferSize,
        PlayerStreamCache.vodBufferBytes,
      );
      expect(
        PlayerStreamCache.configuration(live: true).bufferSize,
        PlayerStreamCache.liveBufferBytes,
      );
      expect(
        PlayerStreamCache.vodBufferBytes > PlayerStreamCache.liveBufferBytes,
        isTrue,
      );
    });
  });
}
