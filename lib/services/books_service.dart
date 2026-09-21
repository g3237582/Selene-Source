import '../models/book.dart';
import '../search/all_source_search.dart';
import '../utils/book_catalog.dart';
import '../utils/json_records.dart';
import '../utils/paged_list.dart';
import 'api_service.dart';

class BooksService {
  static Future<List<BookSource>> getSources({String query = ''}) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/books/sources',
      queryParameters: {
        if (query.isNotEmpty) 'q': query,
        'page': '1',
        'pageSize': '50',
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '获取书源失败');
    }
    final sources = response.data!['sources'] as List? ?? [];
    return sources
        .whereType<Map>()
        .map((item) => BookSource.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<List<BookItem>> search({
    required String query,
    String? sourceId,
  }) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/books/search',
      queryParameters: {
        'q': query,
        if (sourceId != null && sourceId.isNotEmpty) 'sourceId': sourceId,
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '搜索电子书失败');
    }
    final results = response.data!['results'] as List? ?? [];
    return results
        .whereType<Map>()
        .map((item) => BookItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static List<BookSource> searchableSources(List<BookSource> sources) {
    return [
      for (final source in sources)
        if (source.searchSupported && source.id.isNotEmpty) source,
    ];
  }

  static Future<AllSourcePage<BookItem>> searchAll({
    required String query,
    required List<BookSource> sources,
  }) {
    return AllSourceSearch.fetch(
      sourceIds: [
        for (final source in searchableSources(sources)) source.id,
      ],
      search: (sourceId, _) async {
        final items = await search(query: query, sourceId: sourceId);
        return PagedResult(items: items, hasMore: false);
      },
    );
  }

  static Future<BookCatalog> catalog({
    required String sourceId,
    String href = '',
  }) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/books/catalog',
      queryParameters: {
        'sourceId': sourceId,
        if (href.isNotEmpty) 'href': href,
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '获取书源目录失败');
    }
    final entries = (response.data!['entries'] as List? ?? [])
        .whereType<Map>()
        .map((item) => BookItem.fromJson(Map<String, dynamic>.from(item)))
        .where(isReadableBookItem)
        .toList();
    final navigation = (response.data!['navigation'] as List? ?? [])
        .whereType<Map>()
        .map((item) => BookNavLink.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.href.isNotEmpty && item.title.isNotEmpty && item.title != '目录')
        .toList();
    final nextHref = response.data!['nextHref']?.toString() ?? '';
    return BookCatalog(
      entries: entries,
      navigation: navigation,
      nextHref: nextHref,
    );
  }

  static Future<BookItem> getDetail(BookItem book) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      '/api/books/detail',
      body: {
        'sourceId': book.sourceId,
        'bookId': book.id,
        'href': book.detailHref,
        'title': book.title,
        'author': book.author,
        'cover': book.cover,
        'summary': book.summary,
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '获取书籍详情失败');
    }
    return BookItem.fromJson(response.data!);
  }

  static Future<List<BookChapter>> getChapters(BookItem book) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/books/read/chapters',
      queryParameters: {
        'sourceId': book.sourceId,
        'bookId': book.id,
        if (book.detailHref.isNotEmpty) 'href': book.detailHref,
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '获取章节目录失败');
    }
    final chapters = response.data!['chapters'] as List? ?? [];
    return chapters
        .whereType<Map>()
        .map((item) => BookChapter.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<BookChapterContent> getChapter({
    required BookItem book,
    required BookChapter chapter,
  }) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      '/api/books/read/chapter',
      queryParameters: {
        'sourceId': book.sourceId,
        'href': chapter.href,
        if (book.detailHref.isNotEmpty) 'tocHref': book.detailHref,
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '获取章节内容失败');
    }
    return BookChapterContent.fromJson(response.data!);
  }

  static Future<List<BookItem>> getShelf() async {
    final response = await ApiService.get('/api/books/shelf');
    if (!response.success) {
      throw Exception(response.message ?? '获取电子书架失败');
    }
    return asRecordList(response.data).map(BookItem.fromJson).toList();
  }

  static Future<void> addToShelf(BookItem book) async {
    final response = await ApiService.post(
      '/api/books/shelf',
      body: {
        'key': book.shelfKey,
        'item': {
          'sourceId': book.sourceId,
          'sourceName': book.sourceName,
          'bookId': book.id,
          'title': book.title,
          'author': book.author,
          'cover': book.cover,
          'format': book.format.isEmpty ? 'chapters' : book.format,
          'detailHref': book.detailHref,
          'saveTime': DateTime.now().millisecondsSinceEpoch,
        },
      },
    );
    if (!response.success) {
      throw Exception(response.message ?? '加入书架失败');
    }
  }

  static Future<List<BookItem>> getHistory() async {
    final response = await ApiService.get('/api/books/history');
    if (!response.success) {
      throw Exception(response.message ?? '获取阅读历史失败');
    }
    return asRecordList(response.data).map(BookItem.fromJson).toList();
  }

  static Future<void> saveHistory({
    required BookItem book,
    required BookChapter chapter,
  }) async {
    await ApiService.post(
      '/api/books/history',
      body: {
        'key': book.shelfKey,
        'record': {
          'sourceId': book.sourceId,
          'sourceName': book.sourceName,
          'bookId': book.id,
          'title': book.title,
          'author': book.author,
          'cover': book.cover,
          'format': 'chapters',
          'detailHref': book.detailHref,
          'locator': {
            'type': 'chapter',
            'value': chapter.href,
            'href': chapter.href,
            'chapterTitle': chapter.title,
          },
          'progressPercent': 0,
          'chapterTitle': chapter.title,
          'chapterHref': chapter.href,
          'saveTime': DateTime.now().millisecondsSinceEpoch,
        },
      },
    );
  }
}
