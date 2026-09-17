/// Client-side paging for the search result list.
class SearchListPaging {
  static const int pageSize = 24;

  static int pageCount({
    required int totalItems,
    int pageSize = SearchListPaging.pageSize,
  }) {
    if (totalItems <= 0 || pageSize <= 0) {
      return 0;
    }
    return (totalItems + pageSize - 1) ~/ pageSize;
  }

  static int clampPage(int page, int pageCount) {
    if (pageCount <= 0) {
      return 1;
    }
    if (page < 1) {
      return 1;
    }
    if (page > pageCount) {
      return pageCount;
    }
    return page;
  }

  static List<T> pageOf<T>(
    List<T> items,
    int page, {
    int pageSize = SearchListPaging.pageSize,
  }) {
    if (items.isEmpty || pageSize <= 0) {
      return const [];
    }
    final count = pageCount(totalItems: items.length, pageSize: pageSize);
    final current = clampPage(page, count);
    final start = (current - 1) * pageSize;
    if (start >= items.length) {
      return const [];
    }
    final end = start + pageSize;
    return items.sublist(start, end > items.length ? items.length : end);
  }

  static String summaryText({
    required int totalItems,
    required int page,
    required int pageCount,
  }) {
    if (totalItems <= 0) {
      return '共0条';
    }
    return '共$totalItems条  $page/$pageCount';
  }
}
