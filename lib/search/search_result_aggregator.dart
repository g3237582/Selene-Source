import '../models/aggregated_search_result.dart';
import '../models/search_result.dart';

/// Groups source search hits into unique work cards.
///
/// Two hits belong together when they share a normalized title (and year),
/// a distinctive poster file/URL, or the same Douban id.
class SearchResultAggregator {
  static const _genericPosterNames = {
    'cover',
    'poster',
    'default',
    'no',
    'nopic',
    'noposter',
    'placeholder',
    'thumb',
    'pic',
    'image',
    'img',
    'vod',
    'blank',
    'none',
    'null',
    'avatar',
  };

  static final _bracketTag = RegExp(r'【[^】]*】|\[[^\]]*\]');
  static final _trailingYear = RegExp(r'[\(（]\s*(19|20)\d{2}\s*[\)）]');
  static final _qualityTag = RegExp(
    r'(?:^|[\s\(\[【])(?:4k|uhd|1080p|720p|480p|bluray|blu-?ray|web-?dl|\bhd\b|蓝光|高清|超清|国语|粤语|中字|完整版)(?=$|[\s\)\]】])',
    caseSensitive: false,
  );
  static final _punctuation = RegExp(
    r'''[\s`~!@#$%^&*()_\-+=\[\]{}\\|;:'",.<>/?·—–【】（）、，。：；！？「」『』《》]+''',
  );
  static final _digitRun = RegExp(r'\d{6,}');

  static List<AggregatedSearchResult> group(List<SearchResult> results) {
    if (results.isEmpty) {
      return const [];
    }

    final parent = List<int>.generate(results.length, (index) => index);

    int find(int index) {
      var current = index;
      while (parent[current] != current) {
        parent[current] = parent[parent[current]];
        current = parent[current];
      }
      return current;
    }

    void union(int left, int right) {
      final rootLeft = find(left);
      final rootRight = find(right);
      if (rootLeft == rootRight) {
        return;
      }
      if (rootLeft < rootRight) {
        parent[rootRight] = rootLeft;
      } else {
        parent[rootLeft] = rootRight;
      }
    }

    final byTitle = <String, List<int>>{};
    final byPoster = <String, int>{};
    final byDouban = <String, int>{};

    for (var index = 0; index < results.length; index++) {
      final result = results[index];
      final titleKey = normalizeTitle(result.title);
      if (titleKey.isNotEmpty) {
        byTitle.putIfAbsent(titleKey, () => <int>[]).add(index);
      }
      for (final posterKey in posterKeys(result.poster)) {
        final existing = byPoster[posterKey];
        if (existing != null) {
          union(existing, index);
        } else {
          byPoster[posterKey] = index;
        }
      }
      final doubanId = result.doubanId;
      if (doubanId != null && doubanId > 0) {
        final key = doubanId.toString();
        final existing = byDouban[key];
        if (existing != null) {
          union(existing, index);
        } else {
          byDouban[key] = index;
        }
      }
    }

    for (final indices in byTitle.values) {
      _unionByYear(results, indices, union);
    }

    final buckets = <int, List<SearchResult>>{};
    final order = <int>[];
    for (var index = 0; index < results.length; index++) {
      final root = find(index);
      if (!buckets.containsKey(root)) {
        order.add(root);
        buckets[root] = <SearchResult>[];
      }
      buckets[root]!.add(results[index]);
    }

    return [
      for (final root in order) _toAggregated(buckets[root]!),
    ];
  }

  static void _unionByYear(
    List<SearchResult> results,
    List<int> indices,
    void Function(int left, int right) union,
  ) {
    final byYear = <String, List<int>>{};
    for (final index in indices) {
      byYear
          .putIfAbsent(normalizeYear(results[index].year), () => <int>[])
          .add(index);
    }
    for (final yearIndices in byYear.values) {
      for (var offset = 1; offset < yearIndices.length; offset++) {
        union(yearIndices.first, yearIndices[offset]);
      }
    }
    final knownYears =
        byYear.keys.where((year) => year.isNotEmpty).toList(growable: false);
    final unknown = byYear[''];
    if (knownYears.length == 1 && unknown != null) {
      union(byYear[knownYears.first]!.first, unknown.first);
    }
  }

  static AggregatedSearchResult _toAggregated(List<SearchResult> items) {
    var aggregated = AggregatedSearchResult.fromSearchResult(items.first);
    for (var index = 1; index < items.length; index++) {
      aggregated = aggregated.addResult(items[index]);
    }
    return aggregated;
  }

  static String normalizeTitle(String raw) {
    var title = raw.trim().toLowerCase();
    title = title.replaceAll(_bracketTag, '');
    title = title.replaceAll(_trailingYear, '');
    title = title.replaceAll(_qualityTag, '');
    title = title.replaceAll(_punctuation, '');
    return title;
  }

  static String normalizeYear(String raw) {
    final match = RegExp(r'(19|20)\d{2}').firstMatch(raw);
    return match?.group(0) ?? '';
  }

  static List<String> posterKeys(String poster) {
    final trimmed = poster.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return const [];
    }
    final path = uri.path.toLowerCase();
    if (path.isEmpty) {
      return const [];
    }
    final file = path.split('/').last;
    final dot = file.lastIndexOf('.');
    final name = dot <= 0 ? file : file.substring(0, dot);
    if (_genericPosterNames.contains(name)) {
      return const [];
    }
    final keys = <String>[];
    if (uri.host.isNotEmpty) {
      keys.add('url:${uri.host.toLowerCase()}$path');
    }
    if (_isDistinctivePosterName(name)) {
      keys.add('file:$file');
    }
    return keys;
  }

  static bool _isDistinctivePosterName(String name) {
    if (name.length >= 10) {
      return true;
    }
    return _digitRun.hasMatch(name);
  }
}
