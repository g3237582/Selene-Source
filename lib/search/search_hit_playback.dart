import '../models/aggregated_search_result.dart';
import '../models/search_result.dart';
import 'search_result_aggregator.dart';

/// Arguments used to open a video search hit on the player.
///
/// The player shows 「未找到匹配结果」 when its follow-up search is empty and it
/// was not given a source key plus id, because only then does it call
/// `/api/detail`. Aggregated cards used to pass a title parsed out of
/// `标题_年份_类型`, so a title that itself contains `_` sent the wrong year,
/// and special-source hits were re-queried without `special=1`.
class SearchHitPlayback {
  final String? source;
  final String? id;
  final String title;
  final String? year;
  final String? stype;
  final String? stitle;
  final bool prefer;
  final bool special;

  const SearchHitPlayback({
    required this.source,
    required this.id,
    required this.title,
    required this.year,
    required this.stype,
    required this.stitle,
    required this.prefer,
    required this.special,
  });

  /// Grouped card. Year is the card year, not a split of the aggregation key.
  factory SearchHitPlayback.aggregated({
    required AggregatedSearchResult card,
    required String query,
    required bool special,
  }) {
    final primary =
        card.originalResults.isEmpty ? null : card.originalResults.first;
    final year = card.year.trim();
    return SearchHitPlayback(
      source: _nonEmpty(primary?.source),
      id: _nonEmpty(primary?.id),
      title: card.title,
      year: year.isEmpty ? null : year,
      // One episode is a movie. Zero episodes is not: the list hit often has
      // no play URLs yet, and `/api/detail` is what fills them in.
      stype: card.mostCommonEpisodeCount == 1 ? 'movie' : 'tv',
      stitle: query,
      prefer: true,
      special: special,
    );
  }

  factory SearchHitPlayback.single({
    required SearchResult result,
    required String query,
    required bool special,
  }) {
    final year = result.year.trim();
    return SearchHitPlayback(
      source: _nonEmpty(result.source),
      id: _nonEmpty(result.id),
      title: result.title,
      year: year.isEmpty ? null : year,
      stype: result.episodes.length > 1 ? 'tv' : 'movie',
      stitle: query,
      prefer: false,
      special: special,
    );
  }

  static SearchHitPlayback? fromAggregatedList({
    required List<SearchResult> results,
    required Map<String, String> posterHashes,
    required String cardKey,
    required String query,
    required bool special,
  }) {
    final grouped = SearchResultAggregator.group(
      results,
      posterHashes: posterHashes,
    );
    for (final card in grouped) {
      if (card.key == cardKey) {
        return SearchHitPlayback.aggregated(
          card: card,
          query: query,
          special: special,
        );
      }
    }
    return null;
  }

  static String? _nonEmpty(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  /// Query for `GET /api/detail`.
  ///
  /// `special=1` selects the special-source set. Without it the server only
  /// searches ordinary sources and answers 400 for a special-source key.
  /// `title` lets the server fall back to a title search on that source when
  /// a direct id lookup misses.
  static Map<String, String> detailQuery({
    required String source,
    required String id,
    String? title,
    required bool special,
  }) {
    final params = <String, String>{
      'source': source,
      'id': id,
    };
    final trimmed = title?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      params['title'] = trimmed;
    }
    if (special) {
      params['special'] = '1';
    }
    return params;
  }
}

/// Chooses the playable source after a title search and an optional detail call.
class PlaybackSourceSelection {
  final List<SearchResult> sources;
  final SearchResult? current;

  const PlaybackSourceSelection({
    required this.sources,
    required this.current,
  });

  bool get found => current != null;

  static bool matchesQuery(
    SearchResult result, {
    required String title,
    String? year,
    String? stype,
  }) {
    final titleMatch = result.title.replaceAll(' ', '').toLowerCase() ==
        title.replaceAll(' ', '').toLowerCase();
    final yearMatch =
        year == null || result.year.toLowerCase() == year.toLowerCase();
    var typeMatch = true;
    if (stype == 'tv') {
      typeMatch = result.episodes.length > 1;
    } else if (stype == 'movie') {
      typeMatch = result.episodes.length == 1;
    }
    return titleMatch && yearMatch && typeMatch;
  }

  static bool sameIdentity(SearchResult result, String source, String id) {
    return result.source == source && result.id == id;
  }

  /// Title matches stay available for source switching. The tapped source is
  /// taken from `/api/detail` when the follow-up search did not include it,
  /// instead of replacing the whole list with an empty detail response.
  static PlaybackSourceSelection resolve({
    required List<SearchResult> searched,
    required List<SearchResult> detail,
    required String title,
    String? year,
    String? stype,
    String source = '',
    String id = '',
    bool needPrefer = false,
  }) {
    final filtered = searched
        .where(
          (result) => matchesQuery(
            result,
            title: title,
            year: year,
            stype: stype,
          ),
        )
        .toList();

    var sources = filtered;
    if (source.isNotEmpty &&
        id.isNotEmpty &&
        !sources.any((result) => sameIdentity(result, source, id)) &&
        detail.isNotEmpty) {
      sources = [
        ...detail,
        ...sources.where((result) => !sameIdentity(result, source, id)),
      ];
    }

    if (sources.isEmpty) {
      return const PlaybackSourceSelection(sources: [], current: null);
    }

    SearchResult? current = sources.first;
    if (source.isNotEmpty && id.isNotEmpty && !needPrefer) {
      final matches =
          sources.where((result) => sameIdentity(result, source, id));
      current = matches.isEmpty ? null : matches.first;
    }
    return PlaybackSourceSelection(sources: sources, current: current);
  }
}
