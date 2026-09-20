import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MainLayout keeps the mini player and does not mount an in-app island',
      () {
    final source = File('lib/widgets/main_layout.dart').readAsStringSync();
    expect(source.contains('MusicDynamicIsland'), isFalse);
    expect(source.contains('music_dynamic_island'), isFalse);
    expect(source.contains('MusicMiniPlayer'), isTrue);
  });

  test('unused island sources are not shipped', () {
    expect(File('lib/widgets/music_dynamic_island.dart').existsSync(), isFalse);
    expect(
      File('lib/services/music_player_route_tracker.dart').existsSync(),
      isFalse,
    );
    expect(File('test/music_dynamic_island_test.dart').existsSync(), isFalse);
  });

  test('full player is not wired to an island-only route tracker', () {
    final source = File('lib/screens/music_player_screen.dart').readAsStringSync();
    expect(source.contains('MusicPlayerRouteTracker'), isFalse);
    expect(source.contains('music_player_route_tracker'), isFalse);
  });

  test('system MediaSession still initializes at startup and on play', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main.contains('MusicMediaSession.ensureInitialized()'), isTrue);

    final player = File('lib/services/music_player_service.dart').readAsStringSync();
    expect(player.contains('await onActiveSession?.call()'), isTrue);

    final session = File('lib/music/music_media_session.dart').readAsStringSync();
    expect(
      session.contains(
        'MusicPlayerService.onActiveSession = requestNotificationPermission',
      ),
      isTrue,
    );
  });
}
