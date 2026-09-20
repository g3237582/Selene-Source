import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:selene/music/music_media_session.dart';

void main() {
  test('media notification uses a white-on-transparent status drawable', () {
    expect(
      MusicMediaSession.androidNotificationIcon,
      'drawable/ic_stat_music',
    );
    expect(
      MusicMediaSession.androidNotificationIcon.startsWith('mipmap/'),
      isFalse,
    );
    expect(
      MusicMediaSession.audioServiceConfig.androidNotificationIcon,
      MusicMediaSession.androidNotificationIcon,
    );
  });

  test('media notification color is opaque so MediaStyle seek UI can render', () {
    final color = MusicMediaSession.audioServiceConfig.notificationColor;
    expect(color, isNotNull);
    expect(color!.a, 1.0);
    expect(color, MusicMediaSession.notificationColor);
  });

  test('ic_stat_music is a white-on-transparent vector drawable', () {
    final file = File('android/app/src/main/res/drawable/ic_stat_music.xml');
    expect(file.existsSync(), isTrue, reason: 'status-bar media icon must be checked in');

    final xml = file.readAsStringSync();
    expect(xml, contains('<vector'));
    expect(
      xml.contains(RegExp(r'android:fillColor="#(?:FF)?FFFFFF"', caseSensitive: false)),
      isTrue,
      reason: 'notification small icons must be white so OEM MediaStyle cards accept them',
    );
    expect(xml.contains('@mipmap'), isFalse);
    expect(
      xml,
      contains('colored launcher mipmaps'),
      reason: 'document why this resource exists instead of mipmap/launcher_icon',
    );
  });
}
