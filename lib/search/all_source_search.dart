import '../utils/paged_list.dart';

/// One aggregated page of an all-source (全源) catalog search.
class AllSourcePage<T> {
  const AllSourcePage({
    required this.items,
    this.nextPages = const {},
    this.nextTokens = const {},
    this.failedSourceIds = const [],
    this.queriedSourceIds = const [],
  });

  final List<T> items;

  /// Sources that still have a following page, mapped to the next page number.
  final Map<String, int> nextPages;

  /// Sources that still have a following catalog href / cursor.
  final Map<String, String> nextTokens;
  final List<String> failedSourceIds;
  final List<String> queriedSourceIds;

  bool get hasMore => nextPages.isNotEmpty || nextTokens.isNotEmpty;

  bool get allFailed =>
      queriedSourceIds.isNotEmpty &&
      failedSourceIds.length >= queriedSourceIds.length &&
      items.isEmpty;

  String? get errorMessage {
    if (queriedSourceIds.isEmpty) {
      return AllSourceSearch.noSourcesMessage;
    }
    if (allFailed) {
      return AllSourceSearch.allFailedMessage;
    }
    return null;
  }

  String? get recommendErrorMessage {
    if (queriedSourceIds.isEmpty) {
      return AllSourceSearch.noRecommendSourcesMessage;
    }
    if (allFailed) {
      return AllSourceSearch.allRecommendFailedMessage;
    }
    return null;
  }

  PagedResult<T> toPagedResult() {
    return PagedResult(items: items, hasMore: hasMore);
  }
}

/// Concurrent search across enabled sources, matching video multi-source search.
///
/// First page queries every source at page 1. Later pages only query sources
/// that still reported [PagedResult.hasMore]. One source failing does not
/// discard the others.
enum AllSourceHomeKind { manga, book, musicBoard, musicPlaylist }

class AllSourceSearch {
  static const noSourcesMessage = '暂无可用搜索源';
  static const allFailedMessage = '全源搜索失败，请稍后重试';
  static const noRecommendSourcesMessage = '暂无可用推荐源';
  static const allRecommendFailedMessage = '全源推荐失败，请稍后重试';

  static String homeEmptyLabel({
    required AllSourceHomeKind kind,
    bool allSources = true,
  }) {
    switch (kind) {
      case AllSourceHomeKind.manga:
        return allSources ? '暂无推荐漫画' : '暂无漫画';
      case AllSourceHomeKind.book:
        return allSources ? '暂无推荐书籍' : '暂无书籍';
      case AllSourceHomeKind.musicBoard:
        return allSources ? '暂无排行榜' : '当前音源暂无排行榜数据';
      case AllSourceHomeKind.musicPlaylist:
        return allSources ? '暂无推荐歌单' : '当前音源暂无推荐歌单数据';
    }
  }

  static List<T> interleave<T>(Iterable<Iterable<T>> groups) {
    final lists = [
      for (final group in groups) List<T>.from(group, growable: false),
    ];
    if (lists.isEmpty) {
      return <T>[];
    }
    final result = <T>[];
    var index = 0;
    var added = true;
    while (added) {
      added = false;
      for (final list in lists) {
        if (index < list.length) {
          result.add(list[index]);
          added = true;
        }
      }
      index++;
    }
    return result;
  }

  static Future<AllSourcePage<T>> fetch<T>({
    required List<String> sourceIds,
    required Future<PagedResult<T>> Function(String sourceId, int page) search,
    Map<String, int> pages = const {},
    void Function(AllSourcePage<T> partial)? onPartial,
  }) async {
    final ids = _uniqueSourceIds(sourceIds);
    final targets = pages.isEmpty
        ? {for (final id in ids) id: 1}
        : {
            for (final id in ids)
              if (pages.containsKey(id)) id: pages[id]!,
          };
    final orderedIds = [for (final id in ids) if (targets.containsKey(id)) id];
    if (orderedIds.isEmpty) {
      return AllSourcePage<T>(items: const []);
    }

    final groups = List<List<T>?>.filled(orderedIds.length, null);
    final nextPages = <String, int>{};
    final failedSourceIds = <String>[];
    final pending = orderedIds.toSet();

    AllSourcePage<T> snapshot({required List<T> items}) {
      return AllSourcePage<T>(
        items: items,
        nextPages: {
          ...nextPages,
          for (final id in pending) id: targets[id]!,
        },
        failedSourceIds: List<String>.from(failedSourceIds),
        queriedSourceIds: orderedIds,
      );
    }

    await Future.wait([
      for (var index = 0; index < orderedIds.length; index++)
        _searchOne(search, orderedIds[index], targets[orderedIds[index]]!).then((outcome) {
          final id = orderedIds[index];
          pending.remove(id);
          if (outcome.failed) {
            failedSourceIds.add(id);
            return;
          }
          groups[index] = outcome.items;
          if (outcome.hasMore) {
            nextPages[id] = targets[id]! + 1;
          }
          if (onPartial != null && outcome.items.isNotEmpty) {
            onPartial(snapshot(items: outcome.items));
          }
        }),
    ]);

    return AllSourcePage<T>(
      items: interleave([
        for (final group in groups)
          if (group != null) group,
      ]),
      nextPages: nextPages,
      failedSourceIds: failedSourceIds,
      queriedSourceIds: orderedIds,
    );
  }

  /// Concurrent home/catalog feeds that page with opaque hrefs or tokens.
  ///
  /// An empty [cursors] map queries every source at its root (empty token).
  /// Later pages only query sources that still returned [PagedResult.nextToken].
  static Future<AllSourcePage<T>> fetchCursors<T>({
    required List<String> sourceIds,
    required Future<PagedResult<T>> Function(String sourceId, String cursor)
        fetch,
    Map<String, String> cursors = const {},
    void Function(AllSourcePage<T> partial)? onPartial,
  }) async {
    final ids = _uniqueSourceIds(sourceIds);
    final targets = cursors.isEmpty
        ? {for (final id in ids) id: ''}
        : {
            for (final id in ids)
              if (cursors.containsKey(id)) id: cursors[id]!,
          };
    final orderedIds = [for (final id in ids) if (targets.containsKey(id)) id];
    if (orderedIds.isEmpty) {
      return AllSourcePage<T>(items: const []);
    }

    final groups = List<List<T>?>.filled(orderedIds.length, null);
    final nextTokens = <String, String>{};
    final failedSourceIds = <String>[];
    final pending = orderedIds.toSet();

    AllSourcePage<T> snapshot({required List<T> items}) {
      return AllSourcePage<T>(
        items: items,
        nextTokens: {
          ...nextTokens,
          for (final id in pending) id: targets[id]!,
        },
        failedSourceIds: List<String>.from(failedSourceIds),
        queriedSourceIds: orderedIds,
      );
    }

    await Future.wait([
      for (var index = 0; index < orderedIds.length; index++)
        _searchOne(
          (id, _) => fetch(id, targets[id]!),
          orderedIds[index],
          1,
        ).then((outcome) {
          final id = orderedIds[index];
          pending.remove(id);
          if (outcome.failed) {
            failedSourceIds.add(id);
            return;
          }
          groups[index] = outcome.items;
          if (outcome.hasMore && outcome.nextToken.isNotEmpty) {
            nextTokens[id] = outcome.nextToken;
          }
          if (onPartial != null && outcome.items.isNotEmpty) {
            onPartial(snapshot(items: outcome.items));
          }
        }),
    ]);

    return AllSourcePage<T>(
      items: interleave([
        for (final group in groups)
          if (group != null) group,
      ]),
      nextTokens: nextTokens,
      failedSourceIds: failedSourceIds,
      queriedSourceIds: orderedIds,
    );
  }

  static List<String> _uniqueSourceIds(List<String> sourceIds) {
    final seen = <String>{};
    final ids = <String>[];
    for (final id in sourceIds) {
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      ids.add(id);
    }
    return ids;
  }

  static Future<_SourceOutcome<T>> _searchOne<T>(
    Future<PagedResult<T>> Function(String sourceId, int page) search,
    String sourceId,
    int page,
  ) async {
    try {
      final result = await search(sourceId, page);
      return _SourceOutcome(
        items: result.items,
        hasMore: result.hasMore,
        nextToken: result.nextToken,
      );
    } catch (_) {
      return const _SourceOutcome.failed();
    }
  }
}

class _SourceOutcome<T> {
  const _SourceOutcome({
    required this.items,
    required this.hasMore,
    this.nextToken = '',
    this.failed = false,
  });

  const _SourceOutcome.failed()
      : items = const [],
        hasMore = false,
        nextToken = '',
        failed = true;

  final List<T> items;
  final bool hasMore;
  final String nextToken;
  final bool failed;
}
