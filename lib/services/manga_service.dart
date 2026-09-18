import '../models/manga.dart';
import '../utils/json_records.dart';
import 'api_service.dart';

class MangaService {
  static Future<List<MangaSource>> getSources() async {
    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/manga/sources',
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '获取漫画源失败');
    }
    final sources = response.data!['sources'] as List? ?? [];
    return sources
        .whereType<Map>()
        .map((item) => MangaSource.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<List<MangaItem>> search({
    required String query,
    String? sourceId,
    int page = 1,
  }) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/manga/search',
      queryParameters: {
        'q': query,
        if (sourceId != null && sourceId.isNotEmpty) 'sourceId': sourceId,
        'page': '$page',
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '搜索漫画失败');
    }
    final results = response.data!['results'] as List? ?? [];
    return results
        .whereType<Map>()
        .map((item) => MangaItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<List<MangaItem>> recommend({
    required String sourceId,
    int page = 1,
    String type = 'POPULAR',
  }) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/manga/recommend',
      queryParameters: {
        'sourceId': sourceId,
        'page': '$page',
        'type': type,
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '获取推荐漫画失败');
    }
    final mangas = response.data!['mangas'] as List? ?? [];
    return mangas
        .whereType<Map>()
        .map((item) => MangaItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<MangaDetail> getDetail({
    required String mangaId,
    required String sourceId,
    String? title,
    String? cover,
    String? sourceName,
  }) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/manga/detail',
      queryParameters: {
        'mangaId': mangaId,
        'sourceId': sourceId,
        if (title != null && title.isNotEmpty) 'title': title,
        if (cover != null && cover.isNotEmpty) 'cover': cover,
        if (sourceName != null && sourceName.isNotEmpty) 'sourceName': sourceName,
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '获取漫画详情失败');
    }
    return MangaDetail.fromJson(response.data!);
  }

  static Future<List<String>> getPages(String chapterId) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/manga/pages',
      queryParameters: {'chapterId': chapterId},
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '获取章节图片失败');
    }
    return (response.data!['pages'] as List? ?? [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static Future<List<MangaShelfItem>> getShelf() async {
    final response = await ApiService.get(
      '/api/manga/shelf',
    );
    if (!response.success) {
      throw Exception(response.message ?? '获取漫画书架失败');
    }
    return asRecordList(response.data)
        .map(MangaShelfItem.fromJson)
        .toList();
  }

  static Future<void> addToShelf(MangaItem item) async {
    final response = await ApiService.post(
      '/api/manga/shelf',
      body: {
        'key': item.shelfKey,
        'item': {
          'title': item.title,
          'cover': item.cover,
          'sourceId': item.sourceId,
          'sourceName': item.sourceName,
          'mangaId': item.id,
          'description': item.description,
          'author': item.author,
          'status': item.status,
          'saveTime': DateTime.now().millisecondsSinceEpoch,
        },
      },
    );
    if (!response.success) {
      throw Exception(response.message ?? '加入书架失败');
    }
  }

  static Future<void> removeFromShelf(String sourceId, String mangaId) async {
    final key = Uri.encodeQueryComponent('$sourceId+$mangaId');
    final response = await ApiService.delete('/api/manga/shelf?key=$key');
    if (!response.success) {
      throw Exception(response.message ?? '移出书架失败');
    }
  }

  static Future<List<MangaReadRecord>> getHistory() async {
    final response = await ApiService.get('/api/manga/history');
    if (!response.success) {
      throw Exception(response.message ?? '获取漫画阅读历史失败');
    }
    return asRecordList(response.data)
        .map(MangaReadRecord.fromJson)
        .toList();
  }

  static Future<void> saveHistory({
    required MangaItem manga,
    required MangaChapter chapter,
    required int pageIndex,
    required int pageCount,
  }) async {
    await ApiService.post(
      '/api/manga/history',
      body: {
        'key': manga.shelfKey,
        'record': {
          'title': manga.title,
          'cover': manga.cover,
          'sourceId': manga.sourceId,
          'sourceName': manga.sourceName,
          'mangaId': manga.id,
          'chapterId': chapter.id,
          'chapterName': chapter.name,
          'pageIndex': pageIndex,
          'pageCount': pageCount,
          'saveTime': DateTime.now().millisecondsSinceEpoch,
        },
      },
    );
  }
}
