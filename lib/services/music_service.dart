import '../models/music_discovery.dart';
import '../models/music_track.dart';
import '../utils/paged_list.dart';
import 'api_service.dart';
import 'user_data_service.dart';

class MusicService {
  static Future<PagedResult<MusicTrack>> search({
    required String query,
    String source = 'wy',
    int page = 1,
  }) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/music/v2/search',
      queryParameters: {
        'q': query,
        'source': source,
        'type': 'song',
        'page': '$page',
        'limit': '20',
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '搜索歌曲失败');
    }
    final payload = response.data!;
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    final list = (data['list'] as List? ?? [])
        .whereType<Map>()
        .map((item) => MusicTrack.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return PagedResult(
      items: list,
      hasMore: data['hasMore'] == true ||
          inferHasMore(itemCount: list.length, pageSize: 20),
    );
  }

  static Future<MusicPlayResult> play(MusicTrack track) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      '/api/music/v2/play',
      body: {
        'song': track.toPlayBody(),
        'quality': '320k',
        'includeUrl': true,
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '获取播放地址失败');
    }
    final payload = response.data!;
    if (payload['success'] == false) {
      final error = payload['error'];
      final message = error is Map
          ? (error['message']?.toString() ?? '获取播放地址失败')
          : '获取播放地址失败';
      throw Exception(message);
    }
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    final play = data['play'] is Map
        ? Map<String, dynamic>.from(data['play'] as Map)
        : const <String, dynamic>{};
    final lyric = data['lyric'] is Map
        ? Map<String, dynamic>.from(data['lyric'] as Map)
        : const <String, dynamic>{};
    final songJson = data['song'] is Map
        ? Map<String, dynamic>.from(data['song'] as Map)
        : track.toPlayBody();
    final relativeUrl = play['url']?.toString() ?? '';
    if (relativeUrl.isEmpty) {
      throw Exception('未返回音频地址');
    }
    return MusicPlayResult(
      song: MusicTrack.fromJson(songJson),
      streamUrl: relativeUrl,
      lyric: lyric['lyric']?.toString() ?? '',
      translatedLyric: lyric['tlyric']?.toString() ?? '',
    );
  }

  static Future<List<MusicBoard>> getBoards({String source = 'wy'}) async {
    final data = await _getDiscovery(
      '/api/music/v2/discovery/boards',
      {'source': source},
      '获取排行榜失败',
    );
    return parseMusicBoards(data);
  }

  static const fallbackSources = ['wy', 'tx', 'kg'];

  static Future<MusicSongPage> getBoardSongs({
    required String source,
    required String boardId,
    int page = 1,
  }) async {
    final data = await _getDiscovery(
      '/api/music/v2/discovery/board-songs',
      {
        'source': source,
        'boardId': boardId,
        'page': '$page',
      },
      '获取榜单歌曲失败',
    );
    return parseMusicSongs(data);
  }

  static Future<MusicSongPage> getBoardSongsWithFallback({
    required String source,
    required String boardId,
    required String title,
  }) async {
    try {
      return await getBoardSongs(source: source, boardId: boardId);
    } catch (_) {
      for (final candidate in fallbackSources) {
        if (candidate == source) continue;
        try {
          final boards = await getBoards(source: candidate);
          final match = findBoardByName(boards, title);
          if (match == null) continue;
          return await getBoardSongs(
            source: match.source.isNotEmpty ? match.source : candidate,
            boardId: match.id,
          );
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<MusicPlaylistPage> getSongLists({
    required String source,
    String tagId = '',
    String sortId = 'hot',
    int page = 1,
  }) async {
    final data = await _getDiscovery(
      '/api/music/v2/discovery/songlists',
      {
        'source': source,
        if (tagId.isNotEmpty) 'tagId': tagId,
        'sortId': sortId,
        'page': '$page',
      },
      '获取推荐歌单失败',
    );
    return parseMusicPlaylists(data);
  }

  static Future<List<MusicTag>> getSongListTags({String source = 'wy'}) async {
    final data = await _getDiscovery(
      '/api/music/v2/discovery/songlist-tags',
      {'source': source},
      '获取歌单标签失败',
    );
    return parseMusicHotTags(data);
  }

  static Future<MusicSongPage> getSongListDetail({
    required String source,
    required String id,
    int page = 1,
  }) async {
    final data = await _getDiscovery(
      '/api/music/v2/discovery/songlist-detail',
      {
        'source': source,
        'id': id,
        'page': '$page',
      },
      '获取歌单详情失败',
    );
    return parseMusicSongs(data);
  }

  static Future<Map<String, dynamic>> _getDiscovery(
    String path,
    Map<String, String> query,
    String fallbackError,
  ) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? fallbackError);
    }
    final payload = response.data!;
    if (payload['success'] == false) {
      throw Exception(payload['message']?.toString() ?? fallbackError);
    }
    return payload;
  }

  static Future<String> resolveMediaUrl(String pathOrUrl) async {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    final baseUrl = await UserDataService.getServerUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('服务器地址未配置');
    }
    final cleanBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = pathOrUrl.startsWith('/') ? pathOrUrl : '/$pathOrUrl';
    return '$cleanBase$cleanPath';
  }

  static Future<Map<String, String>> cookieHeaders() async {
    final cookies = await UserDataService.getCookies();
    if (cookies == null || cookies.isEmpty) return const {};
    return {'Cookie': cookies};
  }
}
