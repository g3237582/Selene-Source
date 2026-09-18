import 'package:flutter_test/flutter_test.dart';
import 'package:selene/utils/paged_list.dart';

void main() {
  group('inferHasMore', () {
    test('is true when a full page comes back', () {
      expect(inferHasMore(itemCount: 20, pageSize: 20), isTrue);
    });

    test('is false when the last page is short', () {
      expect(inferHasMore(itemCount: 7, pageSize: 20), isFalse);
    });
  });

  group('PagedListState.append', () {
    test('keeps previous items and advances the next page', () {
      const first = PagedListState<String>();
      final afterFirst = first.append(
        const PagedResult(items: ['a', 'b'], hasMore: true),
      );
      final afterSecond = afterFirst.append(
        const PagedResult(items: ['c'], hasMore: false),
      );

      expect(afterFirst.items, ['a', 'b']);
      expect(afterFirst.nextPage, 2);
      expect(afterFirst.hasMore, isTrue);
      expect(afterSecond.items, ['a', 'b', 'c']);
      expect(afterSecond.nextPage, 3);
      expect(afterSecond.hasMore, isFalse);
    });

    test('reset starts from page 1 with an empty list', () {
      final loaded = const PagedListState<int>().append(
        const PagedResult(items: [1, 2], hasMore: true),
      );
      expect(loaded.reset().nextPage, 1);
      expect(loaded.reset().items, isEmpty);
      expect(loaded.reset().hasMore, isTrue);
    });
  });

  group('shouldLoadMore', () {
    test('fires when the user is near the bottom', () {
      expect(
        shouldLoadMore(
          pixels: 960,
          maxScrollExtent: 1000,
          hasMore: true,
          isBusy: false,
        ),
        isTrue,
      );
    });

    test('fires when content does not fill the viewport', () {
      expect(
        shouldLoadMore(
          pixels: 0,
          maxScrollExtent: 0,
          hasMore: true,
          isBusy: false,
        ),
        isTrue,
      );
    });

    test('does not fire while a request is in flight', () {
      expect(
        shouldLoadMore(
          pixels: 1000,
          maxScrollExtent: 1000,
          hasMore: true,
          isBusy: true,
        ),
        isFalse,
      );
    });
  });
}
