import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Stream-cache settings for media_kit. VOD keeps a forward buffer so the
/// progress bar can show cached range; live keeps a small buffer to bound RAM.
class PlayerStreamCache {
  static const int vodBufferBytes = 64 * 1024 * 1024;
  static const int liveBufferBytes = 8 * 1024 * 1024;
  static const int vodCacheSecs = 60;
  static const int vodReadaheadSecs = 20;

  static PlayerConfiguration configuration({required bool live}) {
    return PlayerConfiguration(
      bufferSize: live ? liveBufferBytes : vodBufferBytes,
    );
  }

  static Player create({required bool live}) {
    return Player(configuration: configuration(live: live));
  }

  /// Applies mpv cache properties. No-ops on web / stubs without setProperty.
  static Future<void> apply(Player player, {required bool live}) async {
    try {
      final platform = player.platform as dynamic;
      if (live) {
        await platform.setProperty('cache', 'no');
        await platform.setProperty(
          'demuxer-max-back-bytes',
          '$liveBufferBytes',
        );
        return;
      }
      await platform.setProperty('cache', 'yes');
      await platform.setProperty('cache-secs', '$vodCacheSecs');
      await platform.setProperty('demuxer-max-bytes', '$vodBufferBytes');
      await platform.setProperty(
        'demuxer-readahead-secs',
        '$vodReadaheadSecs',
      );
    } catch (error) {
      debugPrint('PlayerStreamCache: native cache config skipped $error');
    }
  }
}
