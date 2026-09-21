import '../manga/manga_progress.dart';
import '../models/manga.dart';
import '../search/all_source_search.dart';
import '../utils/json_records.dart';
import '../utils/paged_list.dart';
import '../utils/remote_error.dart';
import 'api_service.dart';
import 'local_mode_storage_service.dart';

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

  static Future<PagedResult<MangaItem>> search({
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
    final results = (response.data!['results'] as List? ?? [])
        .whereType<Map>()
        .map((item) => MangaItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return PagedResult(
      items: results,
      hasMore: resolveHasMore(
        data: response.data!,
        itemCount: results.length,
      ),
    );
  }

  static Future<AllSourcePage<MangaItem>> searchAll({
    required String query,
    required List<MangaSource> sources,
    Map<String, int> pages = const {},
    void Function(AllSourcePage<MangaItem> partial)? onPartial,
  }) {
    return AllSourceSearch.fetch(
      sourceIds: [
        for (final source in sources)
          if (source.id.isNotEmpty) source.id,
      ],
      pages: pages,
      onPartial: onPartial,
      search: (sourceId, page) => search(
        query: query,
        sourceId: sourceId,
        page: page,
      ),
    );
  }

  static List<String> recommendSourceIds(List<MangaSource> sources) {
    final seen = <String>{};
    final ids = <String>[];
    for (final source in sources) {
      if (source.id.isEmpty || !seen.add(source.id)) {
        continue;
      }
      ids.add(source.id);
    }
    return ids;
  }

  static Future<AllSourcePage<MangaItem>> recommendAll({
    required List<MangaSource> sources,
    Map<String, int> pages = const {},
    void Function(AllSourcePage<MangaItem> partial)? onPartial,
  }) {
    final byId = {
      for (final source in sources)
        if (source.id.isNotEmpty) source.id: source,
    };
    return AllSourceSearch.fetch(
      sourceIds: recommendSourceIds(sources),
      pages: pages,
      onPartial: onPartial,
      search: (sourceId, page) async {
        final result = await recommend(sourceId: sourceId, page: page);
        final source = byId[sourceId];
        if (source == null) {
          return result;
        }
        return PagedResult(
          items: [
            for (final item in result.items) item.withSource(source),
          ],
          hasMore: result.hasMore,
        );
      },
    );
  }

  static Future<PagedResult<MangaItem>> recommend({
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
    final mangas = (response.data!['mangas'] as List? ?? [])
        .whereType<Map>()
        .map((item) => MangaItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return PagedResult(
      items: mangas,
      hasMore: resolveHasMore(
        data: response.data!,
        itemCount: mangas.length,
      ),
    );
  }

  static Future<MangaDetail> getDetail({
    required String mangaId,
    required String sourceId,
    String? title,
    String? cover,
    String? sourceName,
    bool confirmAdult = false,
  }) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/manga/detail',
      queryParameters: {
        'mangaId': mangaId,
        'sourceId': sourceId,
        if (title != null && title.isNotEmpty) 'title': title,
        if (cover != null && cover.isNotEmpty) 'cover': cover,
        if (sourceName != null && sourceName.isNotEmpty) 'sourceName': sourceName,
        if (confirmAdult) 'confirmAdult': '1',
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    return _detailFromResponse(response);
  }

  static Future<MangaDetail> sendCommand({
    required String command,
    required String mangaId,
    required String sourceId,
    String? title,
    String? cover,
    String? sourceName,
  }) async {
    if (command == kConfirmAdultCommand) {
      return getDetail(
        mangaId: mangaId,
        sourceId: sourceId,
        title: title,
        cover: cover,
        sourceName: sourceName,
        confirmAdult: true,
      );
    }
    final response = await ApiService.post<Map<String, dynamic>>(
      '/api/manga/command',
      body: {
        'command': command,
        'mangaId': mangaId,
        'sourceId': sourceId,
        if (title != null && title.isNotEmpty) 'title': title,
        if (cover != null && cover.isNotEmpty) 'cover': cover,
        if (sourceName != null && sourceName.isNotEmpty) 'sourceName': sourceName,
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    return _detailFromResponse(response);
  }

  static MangaDetail _detailFromResponse(ApiResponse<Map<String, dynamic>> response) {
    if (!response.success || response.data == null) {
      throw MangaRemoteException(
        parseRemoteError(
          response.message ?? '',
          fallback: '获取漫画详情失败',
          action: response.action,
        ),
      );
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
      throw Exception(
        sanitizeRemoteError(
          response.message ?? '',
          fallback: '获取章节图片失败',
        ),
      );
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
    final local = await LocalModeStorageService.getMangaReadRecords();
    try {
      final response = await ApiService.get('/api/manga/history');
      if (!response.success) {
        return local;
      }
      final remote = asRecordList(response.data)
          .map(MangaReadRecord.fromJson)
          .toList();
      return mergeMangaHistory(remote: remote, local: local);
    } catch (_) {
      return local;
    }
  }

  static Future<MangaReadRecord?> getProgress({
    required String sourceId,
    required String mangaId,
  }) async {
    final history = await getHistory();
    return findMangaProgress(history, sourceId, mangaId);
  }

  static Future<void> saveHistory({
    required MangaItem manga,
    required MangaChapter chapter,
    required int pageIndex,
    required int pageCount,
  }) async {
    final record = MangaReadRecord(
      title: manga.title,
      cover: manga.cover,
      sourceId: manga.sourceId,
      sourceName: manga.sourceName,
      mangaId: manga.id,
      chapterId: chapter.id,
      chapterName: chapter.name,
      pageIndex: pageIndex,
      pageCount: pageCount,
      saveTime: DateTime.now().millisecondsSinceEpoch,
    );
    await LocalModeStorageService.saveMangaReadRecord(record);
    try {
      await ApiService.post(
        '/api/manga/history',
        body: {
          'key': manga.shelfKey,
          'record': record.toJson(),
        },
      );
    } catch (_) {
      // 本地进度已写入，远端同步失败不影响续读。
    }
  }
}
