import 'package:flutter_test/flutter_test.dart';
import 'package:selene/widgets/music_dynamic_island.dart';

void main() {
  test('progress fraction clamps and handles zero duration', () {
    expect(
      musicIslandProgressFraction(
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 100),
      ),
      0.3,
    );
    expect(
      musicIslandProgressFraction(
        position: const Duration(seconds: 5),
        duration: Duration.zero,
      ),
      0.0,
    );
    expect(
      musicIslandProgressFraction(
        position: const Duration(seconds: 200),
        duration: const Duration(seconds: 100),
      ),
      1.0,
    );
  });

  test('visibility hides on full player', () {
    expect(
      shouldShowMusicIsland(hasCurrentTrack: true, isOnFullPlayerRoute: false),
      isTrue,
    );
    expect(
      shouldShowMusicIsland(hasCurrentTrack: true, isOnFullPlayerRoute: true),
      isFalse,
    );
    expect(
      shouldShowMusicIsland(hasCurrentTrack: false, isOnFullPlayerRoute: false),
      isFalse,
    );
  });
}
