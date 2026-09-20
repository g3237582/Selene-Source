import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/music_player_service.dart';
import 'music_audio_handler.dart';

/// Initializes the Android MediaSession / iOS Now Playing card.
class MusicMediaSession {
  static const _permissionChannel = MethodChannel('selene/music_media_session');

  static MusicAudioHandler? handler;
  static bool _permissionRequested = false;

  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static Future<void> ensureInitialized() async {
    if (!isSupported || handler != null) return;
    try {
      late final MusicAudioHandler created;
      await AudioService.init(
        builder: () {
          created = MusicAudioHandler(MusicPlayerService.instance);
          return created;
        },
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'org.moontechlab.selene.music',
          androidNotificationChannelName: '音乐播放',
          androidNotificationChannelDescription: '锁屏与通知栏音乐控制',
          // Keep the MediaSession foreground service while paused so the
          // lock-screen card stays. Ongoing=true is rejected unless
          // androidStopForegroundOnPause is also true.
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
          androidNotificationIcon: 'mipmap/launcher_icon',
          androidNotificationClickStartsActivity: true,
          androidShowNotificationBadge: false,
        ),
      );
      handler = created;
      MusicPlayerService.onActiveSession = requestNotificationPermission;
    } catch (error, stack) {
      debugPrint('Music media session init failed: $error\n$stack');
    }
  }

  static Future<void> requestNotificationPermission() async {
    if (!isSupported ||
        defaultTargetPlatform != TargetPlatform.android ||
        _permissionRequested) {
      return;
    }
    _permissionRequested = true;
    try {
      await _permissionChannel.invokeMethod<void>(
        'requestNotificationPermission',
      );
    } catch (error) {
      debugPrint('Music notification permission request skipped: $error');
    }
  }
}
