import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selene/search/all_source_search.dart';
import 'package:selene/utils/paged_list.dart';

void main() {
  group('AllSourceSearch.interleave', () {
    test('round-robins source pages so one source does not dominate', () {
      expect(
        AllSourceSearch.interleave([
          ['a1', 'a2', 'a3'],
          ['b1'],
          ['c1', 'c2'],
        ]),
        ['a1', 'b1', 'c1', 'a2', 'c2', 'a3'],
      );
    });

    test('skips empty groups', () {
      expect(
        AllSourceSearch.interleave([
          <String>[],
          ['b1', 'b2'],
          <String>[],
        ]),
        ['b1', 'b2'],
      );
    });
  });

  group('AllSourceSearch.fetch', () {
    test('returns a no-source message when the list is empty', () async {
      final page = await AllSourceSearch.fetch<String>(
        sourceIds: const [],
        search: (id, page) async => throw StateError('should not run'),
      );

      expect(page.items, isEmpty);
      expect(page.allFailed, isFalse);
      expect(page.hasMore, isFalse);
      expect(page.errorMessage, AllSourceSearch.noSourcesMessage);
    });

    test('merges first pages from every source in source order', () async {
      final page = await AllSourceSearch.fetch<String>(
        sourceIds: const ['a', 'b'],
        search: (id, page) async {
          return PagedResult(
            items: ['$id-1', '$id-2'],
            hasMore: id == 'b',
          );
        },
      );

      expect(page.items, ['a-1', 'b-1', 'a-2', 'b-2']);
      expect(page.nextPages, {'b': 2});
      expect(page.hasMore, isTrue);
      expect(page.errorMessage, isNull);
    });

    test('keeps other sources when one source fails', () async {
      final page = await AllSourceSearch.fetch<String>(
        sourceIds: const ['a', 'b', 'c'],
        search: (id, page) async {
          if (id == 'b') {
            throw Exception('timeout');
          }
          return PagedResult(items: ['$id-1'], hasMore: false);
        },
      );

      expect(page.items, ['a-1', 'c-1']);
      expect(page.failedSourceIds, ['b']);
      expect(page.allFailed, isFalse);
      expect(page.errorMessage, isNull);
    });

    test('reports allFailed when every source throws', () async {
      final page = await AllSourceSearch.fetch<String>(
        sourceIds: const ['a', 'b'],
        search: (id, page) async => throw Exception('down'),
      );

      expect(page.items, isEmpty);
      expect(page.allFailed, isTrue);
      expect(page.failedSourceIds, ['a', 'b']);
      expect(page.errorMessage, AllSourceSearch.allFailedMessage);
    });

    test('treats successful empty pages as empty, not failure', () async {
      final page = await AllSourceSearch.fetch<String>(
        sourceIds: const ['a', 'b'],
        search: (id, page) async {
          if (id == 'a') {
            throw Exception('down');
          }
          return const PagedResult(items: [], hasMore: false);
        },
      );

      expect(page.items, isEmpty);
      expect(page.allFailed, isFalse);
      expect(page.errorMessage, isNull);
    });

    test('load more only queries sources that still have pages', () async {
      final calls = <String>[];
      final page = await AllSourceSearch.fetch<String>(
        sourceIds: const ['a', 'b', 'c'],
        pages: const {'a': 2, 'c': 3},
        search: (id, page) async {
          calls.add('$id:$page');
          return PagedResult(items: ['$id$page'], hasMore: id == 'c');
        },
      );

      expect(calls, ['a:2', 'c:3']);
      expect(page.items, ['a2', 'c3']);
      expect(page.nextPages, {'c': 4});
    });

    test('dedupes source ids and ignores blanks', () async {
      final seen = <String>[];
      await AllSourceSearch.fetch<String>(
        sourceIds: const ['a', '', 'a', 'b'],
        search: (id, page) async {
          seen.add(id);
          return const PagedResult(items: [], hasMore: false);
        },
      );

      expect(seen, ['a', 'b']);
    });

    test('emits each finished source before slower sources complete', () async {
      final slow = Completer<PagedResult<String>>();
      final partials = <List<String>>[];

      final future = AllSourceSearch.fetch<String>(
        sourceIds: const ['fast', 'slow'],
        search: (id, page) async {
          if (id == 'slow') {
            return slow.future;
          }
          return const PagedResult(items: ['fast-1'], hasMore: false);
        },
        onPartial: (page) => partials.add(List<String>.from(page.items)),
      );

      await Future<void>.delayed(Duration.zero);
      expect(partials, [
        ['fast-1'],
      ]);
      expect(partials.first, isNot(contains('slow-1')));

      slow.complete(const PagedResult(items: ['slow-1'], hasMore: true));
      final page = await future;
      expect(page.items, ['fast-1', 'slow-1']);
      expect(page.nextPages, {'slow': 2});
      expect(partials, [
        ['fast-1'],
        ['slow-1'],
      ]);
    });
  });
}
