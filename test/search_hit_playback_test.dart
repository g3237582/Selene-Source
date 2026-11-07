import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/aggregated_search_result.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/search/search_hit_playback.dart';

SearchResult _result({
  required String id,
  required String title,
  required String source,
  String year = '2024',
  int episodes = 1,
  List<String>? episodeUrls,
}) {
  return SearchResult(
    id: id,
    title: title,
    poster: '',
    episodes: episodeUrls ?? List<String>.filled(episodes, 'https://cdn.example/a.m3u8'),
    episodesTitles: const [],
    source: source,
    sourceName: source,
    year: year,
  );
}

void main() {
  test('search JSON accepts numeric ids and string douban ids', () {
    final parsed = SearchResult.fromJson({
      'id': 8462,
      'title': '繁花',
      'poster': '',
      'episodes': [
        'https://cdn.example/1.m3u8',
        {'playUrl': 'https://cdn.example/2.m3u8'},
      ],
      'source': 'dyttzy',
      'source_name': '电影天堂',
      'year': 2023,
      'class': 1,
      'douban_id': '12345',
    });

    expect(parsed.id, '8462');
    expect(parsed.year, '2023');
    expect(parsed.doubanId, 12345);
    expect(parsed.class_, '1');
    expect(parsed.episodes, [
      'https://cdn.example/1.m3u8',
      'https://cdn.example/2.m3u8',
    ]);
  });

  test('one unparsable hit does not drop the rest of the search page', () {
    final parsed = SearchResult.parseList([
      {
        'id': 1,
        'title': '甲',
        'source': 'a',
        'source_name': 'A',
        'year': '2020',
        'episodes': ['https://cdn.example/a.m3u8', 'https://cdn.example/b.m3u8'],
        'douban_id': '7',
      },
      'not-a-map',
      {
        'id': '2',
        'title': '乙',
        'source': 'b',
        'source_name': 'B',
        'year': '2021',
        'episodes': [],
        'douban_id': '',
      },
    ]);

    expect(parsed.map((item) => item.id), ['1', '2']);
    expect(parsed.first.doubanId, 7);
    expect(parsed.last.doubanId, isNull);
  });

  test('aggregated hit keeps the real year, source and special flag', () {
    final result = _result(
      id: '8462',
      title: '间谍过家家_第二季',
      source: 'special-dytt',
      year: '2022',
      episodes: 12,
    );
    final card = AggregatedSearchResult.fromSearchResult(result);

    final hit = SearchHitPlayback.fromAggregatedList(
      results: [result],
      posterHashes: const {},
      cardKey: card.key,
      query: '间谍',
      special: true,
    );

    expect(hit, isNotNull);
    expect(hit!.year, '2022');
    expect(hit.source, 'special-dytt');
    expect(hit.id, '8462');
    expect(hit.stype, 'tv');
    expect(hit.prefer, isTrue);
    expect(hit.special, isTrue);
    expect(hit.stitle, '间谍');
    expect(
      SearchHitPlayback.detailQuery(
        source: hit.source!,
        id: hit.id!,
        title: hit.title,
        special: true,
      ),
      {
        'source': 'special-dytt',
        'id': '8462',
        'title': '间谍过家家_第二季',
        'special': '1',
      },
    );
  });

  test('ordinary detail query does not send special=1', () {
    expect(
      SearchHitPlayback.detailQuery(source: 'dyttzy', id: '1', special: false),
      {'source': 'dyttzy', 'id': '1'},
    );
  });

  test('detail episodes are used when the follow-up search has no play URLs', () {
    final selection = PlaybackSourceSelection.resolve(
      searched: [
        _result(
          id: '8462',
          title: '繁花',
          source: 'dyttzy',
          year: '2023',
          episodeUrls: const [],
        ),
      ],
      detail: [
        _result(
          id: '8462',
          title: '繁花',
          source: 'dyttzy',
          year: '2023',
          episodeUrls: const [
            'https://cdn.example/1.m3u8',
            'https://cdn.example/2.m3u8',
          ],
        ),
      ],
      title: '繁花',
      year: '2023',
      stype: 'movie',
      source: 'dyttzy',
      id: '8462',
    );

    expect(selection.found, isTrue);
    expect(selection.current!.episodes, hasLength(2));
    expect(selection.current!.source, 'dyttzy');
    expect(selection.current!.id, '8462');
  });

  test('a missing exact source does not wipe other title matches when preferring', () {
    final selection = PlaybackSourceSelection.resolve(
      searched: [
        _result(id: '9', title: '繁花', source: 'other', year: '2023', episodes: 8),
      ],
      detail: const [],
      title: '繁花',
      year: '2023',
      stype: 'tv',
      source: 'special-dytt',
      id: '8462',
      needPrefer: true,
    );

    expect(selection.found, isTrue);
    expect(selection.current!.source, 'other');
  });

  test('a specific source tap does not play a different source', () {
    final selection = PlaybackSourceSelection.resolve(
      searched: [
        _result(id: '9', title: '繁花', source: 'other', year: '2023', episodes: 8),
      ],
      detail: const [],
      title: '繁花',
      year: '2023',
      stype: 'tv',
      source: 'dyttzy',
      id: '8462',
    );

    expect(selection.found, isFalse);
  });
}
