import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/search/search_list_paging.dart';
import 'package:selene/search/search_result_aggregator.dart';

SearchResult _result({
  required String id,
  required String title,
  String year = '2024',
  int episodes = 1,
  String source = 'a',
}) {
  return SearchResult(
    id: id,
    title: title,
    poster: '',
    episodes: List<String>.filled(episodes, 'e'),
    episodesTitles: const [],
    source: source,
    sourceName: source,
    year: year,
  );
}

void main() {
  group('SearchListPaging.pageCount', () {
    test('is 0 when there are no items', () {
      expect(SearchListPaging.pageCount(totalItems: 0), 0);
    });

    test('fits a full page onto one page', () {
      expect(
        SearchListPaging.pageCount(totalItems: SearchListPaging.pageSize),
        1,
      );
    });

    test('adds a page for leftover items', () {
      expect(
        SearchListPaging.pageCount(
          totalItems: SearchListPaging.pageSize + 1,
        ),
        2,
      );
    });
  });

  group('SearchListPaging.pageOf', () {
    test('returns the requested slice', () {
      final items = List<int>.generate(50, (index) => index);
      expect(
        SearchListPaging.pageOf(items, 2, pageSize: 24),
        List<int>.generate(24, (index) => index + 24),
      );
    });

    test('returns a short last page', () {
      final items = List<int>.generate(30, (index) => index);
      expect(
        SearchListPaging.pageOf(items, 2, pageSize: 24),
        [24, 25, 26, 27, 28, 29],
      );
    });

    test('clamps an oversized page to the last page', () {
      final items = ['a', 'b', 'c'];
      expect(
        SearchListPaging.pageOf(items, 9, pageSize: 2),
        ['c'],
      );
    });
  });

  group('SearchListPaging.summaryText', () {
    test('shows total count and current/total pages', () {
      expect(
        SearchListPaging.summaryText(totalItems: 86, page: 2, pageCount: 4),
        '共86条  2/4',
      );
    });

    test('shows zero results without a fake page', () {
      expect(
        SearchListPaging.summaryText(totalItems: 0, page: 1, pageCount: 0),
        '共0条',
      );
    });
  });

  group('SearchResultAggregator.group', () {
    test('counts unique title/year/type cards', () {
      final grouped = SearchResultAggregator.group([
        _result(id: '1', title: '同一部', source: '源A'),
        _result(id: '2', title: '同一部', source: '源B'),
        _result(id: '3', title: '另一部', source: '源A'),
      ]);
      expect(grouped, hasLength(2));
      expect(grouped.first.originalResults, hasLength(2));
    });
  });
}
