import 'package:flutter/widgets.dart';

class PagedResult<T> {
  final List<T> items;
  final bool hasMore;
  final String nextToken;

  const PagedResult({
    required this.items,
    this.hasMore = false,
    this.nextToken = '',
  });
}

class PagedListState<T> {
  final List<T> items;
  final int nextPage;
  final bool hasMore;
  final String nextToken;

  const PagedListState({
    this.items = const [],
    this.nextPage = 1,
    this.hasMore = true,
    this.nextToken = '',
  });

  PagedListState<T> reset() => PagedListState<T>();

  PagedListState<T> copyWith({
    List<T>? items,
    int? nextPage,
    bool? hasMore,
    String? nextToken,
  }) {
    return PagedListState<T>(
      items: items ?? this.items,
      nextPage: nextPage ?? this.nextPage,
      hasMore: hasMore ?? this.hasMore,
      nextToken: nextToken ?? this.nextToken,
    );
  }

  PagedListState<T> append(PagedResult<T> page) {
    return PagedListState<T>(
      items: [...items, ...page.items],
      nextPage: nextPage + 1,
      hasMore: page.hasMore,
      nextToken: page.nextToken,
    );
  }
}

bool inferHasMore({required int itemCount, required int pageSize}) {
  return pageSize > 0 && itemCount >= pageSize;
}

bool resolveHasMore({
  required Map<String, dynamic> data,
  required int itemCount,
  int pageSize = 10,
}) {
  final explicit = data['hasNextPage'] ?? data['hasMore'];
  if (explicit == true) {
    return true;
  }
  if (explicit == false) {
    return false;
  }
  return inferHasMore(itemCount: itemCount, pageSize: pageSize);
}

int displayPageCount({
  required int loadedCount,
  required int pageSize,
  required bool remoteHasMore,
}) {
  if (pageSize <= 0 || loadedCount <= 0) {
    return remoteHasMore ? 1 : 0;
  }
  final filled = (loadedCount + pageSize - 1) ~/ pageSize;
  return remoteHasMore ? filled + 1 : filled;
}

int remotePageCount({required int page, required bool hasMore}) {
  final current = page < 1 ? 1 : page;
  return hasMore ? current + 1 : current;
}

String remoteSummaryText({
  required int pageItemCount,
  required int page,
  required int pageCount,
}) {
  if (pageItemCount <= 0) {
    return '共0条';
  }
  return '本页$pageItemCount条  $page/$pageCount';
}

/// Full-screen catalog/search spinners destroy scroll position.
/// Search and pagination must keep the existing scroll view instead.
bool shouldReplaceCatalogWithLoader({
  required bool loading,
  required int itemCount,
}) {
  // itemCount cannot be negative; this stays false so a spinner never
  // replaces an on-screen catalog/search list (including an empty in-flight one).
  return loading && itemCount < 0;
}

bool shouldLoadMore({
  required double pixels,
  required double maxScrollExtent,
  required bool hasMore,
  required bool isBusy,
  double threshold = 50,
}) {
  if (!hasMore || isBusy) {
    return false;
  }
  if (maxScrollExtent <= 0) {
    return true;
  }
  return pixels >= maxScrollExtent - threshold;
}

void handlePagedScroll(
  ScrollController controller, {
  required bool hasMore,
  required bool isBusy,
  required VoidCallback onLoadMore,
}) {
  if (!controller.hasClients) {
    return;
  }
  final position = controller.position;
  if (shouldLoadMore(
    pixels: position.pixels,
    maxScrollExtent: position.maxScrollExtent,
    hasMore: hasMore,
    isBusy: isBusy,
  )) {
    onLoadMore();
  }
}
