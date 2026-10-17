import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../net/windows_system_proxy.dart';

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

  /// libmpv does not use Dart's HttpClient, so copy the same Windows proxy
  /// decision onto mpv `http-proxy`. An empty value keeps a direct connection.
  static Future<void> applyPlaybackProxy(Player player, String url) async {
    if (kIsWeb || !Platform.isWindows) return;
    final uri = Uri.tryParse(url);
    final proxy = uri == null ? '' : WindowsSystemProxy.mpvHttpProxyFor(uri);
    try {
      final platform = player.platform as dynamic;
      await platform.setProperty('http-proxy', proxy);
    } catch (error) {
      debugPrint('PlayerStreamCache: http-proxy skipped $error');
    }
  }
}
