import 'package:flutter_test/flutter_test.dart';
import 'package:selene/search/all_source_search.dart';
import 'package:selene/search/search_page_merge.dart';
import 'package:selene/utils/paged_list.dart';

void main() {
  test('reset keeps the previous list until the first new batch arrives', () {
    final merge = SearchPageMerge<String>(reset: true);
    final previous = const PagedListState<String>().append(
      const PagedResult(items: ['old-1', 'old-2'], hasMore: false),
    );

    expect(merge.absorb(previous, const []), previous);
    expect(merge.replaced, isFalse);

    final first = merge.absorb(previous, const ['new-a']);
    expect(first.items, ['new-a']);
    expect(first.hasMore, isTrue);

    final second = merge.absorb(first, const ['new-b']);
    expect(second.items, ['new-a', 'new-b']);
  });

  test('complete only appends when no partial batch was shown', () {
    final merge = SearchPageMerge<String>(reset: false);
    final current = const PagedListState<String>().append(
      const PagedResult(items: ['a'], hasMore: true),
    );
    const page = AllSourcePage<String>(
      items: ['b'],
      nextPages: {},
      queriedSourceIds: ['s'],
    );

    final finished = merge.complete(current, page);
    expect(finished.items, ['a', 'b']);
    expect(finished.hasMore, isFalse);
  });

  test('complete after partials only updates hasMore', () {
    final merge = SearchPageMerge<String>(reset: true);
    var current = merge.absorb(const PagedListState(), const ['fast']);
    current = merge.complete(
      current,
      const AllSourcePage(
        items: ['fast', 'slow'],
        nextPages: {'slow': 2},
        queriedSourceIds: ['fast', 'slow'],
      ),
    );

    expect(current.items, ['fast']);
    expect(current.hasMore, isTrue);
  });
}
