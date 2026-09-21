import '../utils/paged_list.dart';

/// One aggregated page of an all-source (全源) catalog search.
class AllSourcePage<T> {
  const AllSourcePage({
    required this.items,
    this.nextPages = const {},
    this.failedSourceIds = const [],
    this.queriedSourceIds = const [],
  });

  final List<T> items;

  /// Sources that still have a following page, mapped to the next page number.
  final Map<String, int> nextPages;
  final List<String> failedSourceIds;
  final List<String> queriedSourceIds;

  bool get hasMore => nextPages.isNotEmpty;

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

  PagedResult<T> toPagedResult() {
    return PagedResult(items: items, hasMore: hasMore);
  }
}

/// Concurrent search across enabled sources, matching video multi-source search.
///
/// First page queries every source at page 1. Later pages only query sources
/// that still reported [PagedResult.hasMore]. One source failing does not
/// discard the others.
class AllSourceSearch {
  static const noSourcesMessage = '暂无可用搜索源';
  static const allFailedMessage = '全源搜索失败，请稍后重试';

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

    final outcomes = await Future.wait([
      for (final id in orderedIds) _searchOne(search, id, targets[id]!),
    ]);

    final groups = <List<T>>[];
    final nextPages = <String, int>{};
    final failedSourceIds = <String>[];
    for (var index = 0; index < orderedIds.length; index++) {
      final id = orderedIds[index];
      final outcome = outcomes[index];
      if (outcome.failed) {
        failedSourceIds.add(id);
        continue;
      }
      groups.add(outcome.items);
      if (outcome.hasMore) {
        nextPages[id] = targets[id]! + 1;
      }
    }

    return AllSourcePage<T>(
      items: interleave(groups),
      nextPages: nextPages,
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
    this.failed = false,
  });

  const _SourceOutcome.failed()
      : items = const [],
        hasMore = false,
        failed = true;

  final List<T> items;
  final bool hasMore;
  final bool failed;
}
