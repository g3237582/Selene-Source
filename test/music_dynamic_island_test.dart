import 'package:flutter/material.dart';
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

  testWidgets('collapsed island shows cover and ring when track present',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MusicDynamicIsland(
            debugForceVisible: true,
            debugProgress: 0.25,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('music_dynamic_island')), findsOneWidget);
    expect(find.byKey(const Key('music_dynamic_island_ring')), findsOneWidget);
  });

  testWidgets('tap island toggles expanded controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MusicDynamicIsland(
            debugForceVisible: true,
            debugProgress: 0.25,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('music_island_play')), findsNothing);
    await tester.tap(find.byKey(const Key('music_dynamic_island')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('music_island_play')), findsOneWidget);
    expect(find.byKey(const Key('music_island_prev')), findsOneWidget);
    expect(find.byKey(const Key('music_island_next')), findsOneWidget);
  });
}
