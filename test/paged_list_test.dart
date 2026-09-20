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

  group('resolveHasMore', () {
    test('trusts an explicit next-page flag', () {
      expect(
        resolveHasMore(
          data: const {'hasNextPage': true},
          itemCount: 3,
          pageSize: 20,
        ),
        isTrue,
      );
    });

    test('stops when the API says there is no next page', () {
      expect(
        resolveHasMore(
          data: const {'hasNextPage': false},
          itemCount: 20,
          pageSize: 20,
        ),
        isFalse,
      );
    });

    test('infers another page when the flag is missing and the page is full', () {
      expect(
        resolveHasMore(
          data: const {},
          itemCount: 10,
          pageSize: 10,
        ),
        isTrue,
      );
    });
  });

  group('remotePageCount', () {
    test('exposes a following page while more results exist', () {
      expect(remotePageCount(page: 1, hasMore: true), 2);
      expect(remotePageCount(page: 3, hasMore: true), 4);
    });

    test('stays on the current page when the catalog is exhausted', () {
      expect(remotePageCount(page: 1, hasMore: false), 1);
      expect(remotePageCount(page: 4, hasMore: false), 4);
    });
  });

  group('displayPageCount', () {
    test('splits a remote batch into 24-item pages', () {
      expect(
        displayPageCount(
          loadedCount: 70,
          pageSize: 24,
          remoteHasMore: false,
        ),
        3,
      );
    });

    test('keeps a following page while the remote catalog has more', () {
      expect(
        displayPageCount(
          loadedCount: 70,
          pageSize: 24,
          remoteHasMore: true,
        ),
        4,
      );
    });
  });

  group('remoteSummaryText', () {
    test('shows this page count with the current page index', () {
      expect(
        remoteSummaryText(pageItemCount: 12, page: 1, pageCount: 2),
        '本页12条  1/2',
      );
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
