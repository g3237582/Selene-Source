import '../utils/paged_list.dart';
import 'all_source_search.dart';

/// Merges all-source (or single-page) arrivals into a visible search list
/// without first clearing it. The first batch of a reset replaces the old
/// query; later batches append so scroll offset stays put.
class SearchPageMerge<T> {
  SearchPageMerge({required this.reset});

  final bool reset;
  bool replaced = false;

  PagedListState<T> absorb(PagedListState<T> current, List<T> items) {
    if (items.isEmpty) {
      return current;
    }
    final base = reset && !replaced ? PagedListState<T>() : current;
    replaced = true;
    return base.append(PagedResult(items: items, hasMore: true));
  }

  PagedListState<T> complete(
    PagedListState<T> current,
    AllSourcePage<T> page,
  ) {
    if (!replaced) {
      return (reset ? PagedListState<T>() : current).append(page.toPagedResult());
    }
    return current.copyWith(hasMore: page.hasMore);
  }
}
