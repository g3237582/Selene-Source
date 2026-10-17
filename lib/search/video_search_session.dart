import '../services/user_data_service.dart';

/// Identity that invalidates a cached special-source capability.
class VideoSearchSession {
  final String serverUrl;
  final String username;
  final bool localMode;

  const VideoSearchSession({
    required this.serverUrl,
    required this.username,
    required this.localMode,
  });

  bool differsFrom(VideoSearchSession other) {
    return serverUrl != other.serverUrl ||
        username != other.username ||
        localMode != other.localMode;
  }

  String get key => '$localMode|$serverUrl|$username';

  static Future<VideoSearchSession> current() async {
    return VideoSearchSession(
      serverUrl: await UserDataService.getServerUrl() ?? '',
      username: await UserDataService.getUsername() ?? '',
      localMode: await UserDataService.getIsLocalMode(),
    );
  }
}
