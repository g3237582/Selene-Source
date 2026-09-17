import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/search/search_result_aggregator.dart';

SearchResult _result({
  required String id,
  required String title,
  String year = '2024',
  int episodes = 1,
  String source = 'a',
  String poster = '',
  int? doubanId,
}) {
  return SearchResult(
    id: id,
    title: title,
    poster: poster,
    episodes: List<String>.filled(episodes, 'e'),
    episodesTitles: const [],
    source: source,
    sourceName: source,
    year: year,
    doubanId: doubanId,
  );
}

void main() {
  group('SearchResultAggregator.group', () {
    test('merges titles that only differ by space, brackets, or quality tags', () {
      final grouped = SearchResultAggregator.group([
        _result(id: '1', title: '流浪地球', source: '源A'),
        _result(id: '2', title: ' 流浪地球 ', source: '源B'),
        _result(id: '3', title: '【4K】流浪地球', source: '源C'),
        _result(id: '4', title: '流浪地球(2024)', source: '源D'),
        _result(id: '5', title: '另一部', source: '源A'),
      ]);
      expect(grouped, hasLength(2));
      expect(
        grouped.first.originalResults.map((item) => item.id),
        ['1', '2', '3', '4'],
      );
    });

    test('merges the same work when one source omits the year', () {
      final grouped = SearchResultAggregator.group([
        _result(id: '1', title: '同一部', year: '2024', source: '源A'),
        _result(id: '2', title: '同一部', year: '', source: '源B'),
      ]);
      expect(grouped, hasLength(1));
      expect(grouped.single.originalResults, hasLength(2));
    });

    test('does not merge the same title from different years', () {
      final grouped = SearchResultAggregator.group([
        _result(id: '1', title: '同一部', year: '2019', source: '源A'),
        _result(id: '2', title: '同一部', year: '2023', source: '源B'),
      ]);
      expect(grouped, hasLength(2));
    });

    test('merges season titles even when sources disagree on year', () {
      final grouped = SearchResultAggregator.group([
        _result(id: '1', title: '良医 第四季', year: '2017', source: '源A'),
        _result(id: '2', title: '良医第四季', year: '2025', source: '源B'),
        _result(id: '3', title: '良医第4季', year: '2020', source: '源C'),
      ]);
      expect(grouped, hasLength(1));
      expect(grouped.single.originalResults, hasLength(3));
    });

    test('does not merge a series with a specific season', () {
      final grouped = SearchResultAggregator.group([
        _result(id: '1', title: '良医', year: '2017', source: '源A'),
        _result(id: '2', title: '良医第四季', year: '2017', source: '源B'),
      ]);
      expect(grouped, hasLength(2));
    });

    test('merges commentary retitles that share a poster path', () {
      final grouped = SearchResultAggregator.group([
        _result(
          id: '1',
          title: '奇迹[电影解说]',
          year: '2004',
          source: '源A',
          poster: 'https://a.example.com/upload/vod/5f3a9c2e1b88aa/1.jpg',
        ),
        _result(
          id: '2',
          title: '天赐良医【影视解说】',
          year: '2004',
          source: '源B',
          poster: 'https://b.example.com/upload/vod/5f3a9c2e1b88aa/1.jpg?w=300',
        ),
      ]);
      expect(grouped, hasLength(1));
    });

    test('merges movie and series cuts of the same title', () {
      final grouped = SearchResultAggregator.group([
        _result(id: '1', title: '同一部', episodes: 1, source: '源A'),
        _result(id: '2', title: '同一部', episodes: 24, source: '源B'),
      ]);
      expect(grouped, hasLength(1));
    });

    test('merges different titles that share a distinctive poster', () {
      const poster =
          'https://cdn.example.com/upload/vod/p2884280704.jpg?imageView=1';
      final grouped = SearchResultAggregator.group([
        _result(
          id: '1',
          title: 'The Wandering Earth',
          source: '源A',
          poster: poster,
        ),
        _result(
          id: '2',
          title: '流浪地球',
          source: '源B',
          poster:
              'https://img.other.com/static/p2884280704.jpg',
        ),
      ]);
      expect(grouped, hasLength(1));
      expect(grouped.single.originalResults, hasLength(2));
    });

    test('does not merge different titles that only share a generic poster name', () {
      final grouped = SearchResultAggregator.group([
        _result(
          id: '1',
          title: '影片甲',
          source: '源A',
          poster: 'https://a.example.com/images/cover.jpg',
        ),
        _result(
          id: '2',
          title: '影片乙',
          source: '源B',
          poster: 'https://b.example.com/images/cover.jpg',
        ),
      ]);
      expect(grouped, hasLength(2));
    });

    test('does not merge empty posters', () {
      final grouped = SearchResultAggregator.group([
        _result(id: '1', title: '影片甲', source: '源A', poster: ''),
        _result(id: '2', title: '影片乙', source: '源B', poster: ''),
      ]);
      expect(grouped, hasLength(2));
    });

    test('merges by douban id even when titles differ', () {
      final grouped = SearchResultAggregator.group([
        _result(id: '1', title: '英文名', source: '源A', doubanId: 12345),
        _result(id: '2', title: '中文名', source: '源B', doubanId: 12345),
      ]);
      expect(grouped, hasLength(1));
    });

    test('merges different titles that share a poster dHash', () {
      final grouped = SearchResultAggregator.group(
        [
          _result(
            id: '1',
            title: '奇迹[电影解说]',
            poster: 'https://a.example.com/a.jpg',
          ),
          _result(
            id: '2',
            title: '天赐良医【影视解说】',
            poster: 'https://b.example.com/b.jpg',
          ),
        ],
        posterHashes: {
          'https://a.example.com/a.jpg': '0123456789abcdef',
          'https://b.example.com/b.jpg': '0123456789abcdef',
        },
      );
      expect(grouped, hasLength(1));
    });

    test('merges posters whose dHash only differs by a few bits', () {
      final grouped = SearchResultAggregator.group(
        [
          _result(id: '1', title: '影片甲', poster: 'https://a.example.com/a.jpg'),
          _result(id: '2', title: '影片乙', poster: 'https://b.example.com/b.jpg'),
        ],
        posterHashes: {
          'https://a.example.com/a.jpg': '0000000000000000',
          'https://b.example.com/b.jpg': '0000000000000001',
        },
      );
      expect(grouped, hasLength(1));
    });
  });
}
