import '../models/aggregated_search_result.dart';
import '../models/search_result.dart';
import 'poster_dhash.dart';

/// Parsed work identity: a base title plus an optional season/part number.
class TitleParts {
  const TitleParts({required this.base, this.part});

  final String base;
  final int? part;

  String get canonical => part == null ? base : '$base#$part';

  bool get hasPart => part != null;
}

/// Groups source search hits into unique work cards.
///
/// Two hits belong together when they share a normalized title (and year),
/// a season-qualified title, a distinctive poster file/URL, or the same Douban id.
/// Poster/hash unions are skipped when season/part numbers conflict, so a
/// numbered season is never swallowed by the series or another season.
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
    'upload',
    'static',
    'images',
    'pics',
  };

  static const _chineseDigits = {
    '零': 0,
    '一': 1,
    '二': 2,
    '两': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
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
  static final _hexRun = RegExp(r'^[a-f0-9]{10,}$');
  static final _chineseSeason = RegExp(r'第([零一二两三四五六七八九十百]+)([季部])');
  static final _seasonToken = RegExp(r'第\d+[季部]|s\d+|season\d+');
  static final _explicitSeason = RegExp(r'^(.*)第(\d+)[季部]$');
  static final _seasonWord = RegExp(r'^(.*)season(\d{1,2})$');
  static final _seasonS = RegExp(r'^(.*)s(\d{1,2})$');
  static final _trailingPart = RegExp(r'^(.*[^\d])(\d{1,2})$');
  static final _dateLike = RegExp(r'^(19|20)\d{4,6}$');
  static final _mixedAlnum = RegExp(r'(?=.*[a-z])(?=.*\d)');

  static List<AggregatedSearchResult> group(
    List<SearchResult> results, {
    Map<String, String> posterHashes = const {},
  }) {
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

    final parts = [
      for (final result in results)
        parseTitleParts(normalizeTitle(result.title)),
    ];

    final byTitle = <String, List<int>>{};
    final byPoster = <String, List<int>>{};
    final byDouban = <String, int>{};

    for (var index = 0; index < results.length; index++) {
      final result = results[index];
      final titleKey = parts[index].canonical;
      if (titleKey.isNotEmpty) {
        byTitle.putIfAbsent(titleKey, () => <int>[]).add(index);
      }
      for (final posterKey in posterKeys(result.poster)) {
        byPoster.putIfAbsent(posterKey, () => <int>[]).add(index);
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

    for (final indices in byPoster.values) {
      _unionCompatible(indices, parts, union);
    }
    _unionByPosterHashes(results, posterHashes, parts, union);

    for (final entry in byTitle.entries) {
      if (parts[entry.value.first].hasPart) {
        for (var offset = 1; offset < entry.value.length; offset++) {
          union(entry.value.first, entry.value[offset]);
        }
      } else {
        _unionByYear(results, entry.value, union);
      }
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

  static void _unionByPosterHashes(
    List<SearchResult> results,
    Map<String, String> posterHashes,
    List<TitleParts> parts,
    void Function(int left, int right) union,
  ) {
    if (posterHashes.isEmpty) {
      return;
    }
    final byHash = <String, List<int>>{};
    for (var index = 0; index < results.length; index++) {
      final hash = posterHashes[results[index].poster.trim()];
      if (hash == null || hash.isEmpty) {
        continue;
      }
      byHash.putIfAbsent(hash, () => <int>[]).add(index);
    }
    for (final indices in byHash.values) {
      _unionCompatible(indices, parts, union);
    }
    final unique = byHash.keys.toList(growable: false);
    for (var left = 0; left < unique.length; left++) {
      for (var right = left + 1; right < unique.length; right++) {
        if (!PosterDHash.isMatch(unique[left], unique[right])) {
          continue;
        }
        _unionCompatibleAcross(
          byHash[unique[left]]!,
          byHash[unique[right]]!,
          parts,
          union,
        );
      }
    }
  }

  static void _unionCompatible(
    List<int> indices,
    List<TitleParts> parts,
    void Function(int left, int right) union,
  ) {
    for (var i = 0; i < indices.length; i++) {
      for (var j = i + 1; j < indices.length; j++) {
        if (!titlePartsConflict(parts[indices[i]], parts[indices[j]])) {
          union(indices[i], indices[j]);
        }
      }
    }
  }

  static void _unionCompatibleAcross(
    List<int> left,
    List<int> right,
    List<TitleParts> parts,
    void Function(int left, int right) union,
  ) {
    for (final i in left) {
      for (final j in right) {
        if (!titlePartsConflict(parts[i], parts[j])) {
          union(i, j);
        }
      }
    }
  }

  static bool titlePartsConflict(TitleParts left, TitleParts right) {
    if (left.part == null && right.part == null) {
      return false;
    }
    if (left.part == null || right.part == null) {
      return true;
    }
    return left.part != right.part;
  }

  static TitleParts parseTitleParts(String titleKey) {
    var match = _explicitSeason.firstMatch(titleKey);
    if (match != null && match.group(1)!.isNotEmpty) {
      return TitleParts(
        base: match.group(1)!,
        part: int.parse(match.group(2)!),
      );
    }
    match = _seasonWord.firstMatch(titleKey);
    if (match != null && match.group(1)!.isNotEmpty) {
      final number = int.parse(match.group(2)!);
      if (number >= 1 && number <= 99) {
        return TitleParts(base: match.group(1)!, part: number);
      }
    }
    match = _seasonS.firstMatch(titleKey);
    if (match != null && match.group(1)!.isNotEmpty) {
      final number = int.parse(match.group(2)!);
      if (number >= 1 && number <= 99) {
        return TitleParts(base: match.group(1)!, part: number);
      }
    }
    match = _trailingPart.firstMatch(titleKey);
    if (match != null) {
      final base = match.group(1)!;
      final number = int.parse(match.group(2)!);
      if (base.length >= 2 && number >= 1 && number <= 99) {
        return TitleParts(base: base, part: number);
      }
    }
    return TitleParts(base: titleKey);
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
    title = title.replaceAllMapped(_chineseSeason, (match) {
      final number = parseChineseNumber(match.group(1)!);
      if (number == null) {
        return match.group(0)!;
      }
      return '第$number${match.group(2)}';
    });
    title = title.replaceAll(_punctuation, '');
    return title;
  }

  static bool hasSeasonToken(String titleKey) {
    return parseTitleParts(titleKey).hasPart || _seasonToken.hasMatch(titleKey);
  }

  static int? parseChineseNumber(String raw) {
    if (raw == '十') {
      return 10;
    }
    final single = _chineseDigits[raw];
    if (single != null) {
      return single;
    }
    if (raw.startsWith('十')) {
      final ones = _chineseDigits[raw.substring(1)];
      return ones == null ? null : 10 + ones;
    }
    if (raw.endsWith('十')) {
      final tens = _chineseDigits[raw.substring(0, raw.length - 1)];
      return tens == null ? null : tens * 10;
    }
    final tenIndex = raw.indexOf('十');
    if (tenIndex <= 0) {
      return null;
    }
    final tens = _chineseDigits[raw.substring(0, tenIndex)];
    final ones = tenIndex + 1 < raw.length
        ? _chineseDigits[raw.substring(tenIndex + 1)]
        : 0;
    if (tens == null || ones == null) {
      return null;
    }
    return tens * 10 + ones;
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
    final unwrapped = _unwrapProxyUrl(trimmed);
    final uri = Uri.tryParse(unwrapped);
    if (uri == null) {
      return const [];
    }
    var path = uri.path.toLowerCase();
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.isEmpty) {
      return const [];
    }
    final file = path.split('/').last;
    final dot = file.lastIndexOf('.');
    final name = dot <= 0 ? file : file.substring(0, dot);
    final keys = <String>{};
    if (uri.host.isNotEmpty) {
      keys.add('url:${uri.host.toLowerCase()}$path');
    }
    if (!_genericPosterNames.contains(name) && _isDistinctivePosterName(name)) {
      keys.add('file:$file');
    }
    if (_hasDistinctivePathSegment(path)) {
      keys.add('path:$path');
    }
    return keys.toList(growable: false);
  }

  static String _unwrapProxyUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      return raw;
    }
    final nested = uri.queryParameters['url'];
    if (nested != null && nested.isNotEmpty) {
      return nested;
    }
    return raw;
  }

  static bool _isDistinctivePosterName(String name) {
    if (name.length >= 10) {
      return true;
    }
    return _digitRun.hasMatch(name);
  }

  static bool _hasDistinctivePathSegment(String path) {
    for (final segment in path.split('/')) {
      if (segment.isEmpty || _genericPosterNames.contains(segment)) {
        continue;
      }
      if (_dateLike.hasMatch(segment)) {
        continue;
      }
      if (_hexRun.hasMatch(segment)) {
        return true;
      }
      if (segment.length >= 10 && _mixedAlnum.hasMatch(segment)) {
        return true;
      }
      if (_digitRun.hasMatch(segment)) {
        return true;
      }
    }
    return false;
  }
}
