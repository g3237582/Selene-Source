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
