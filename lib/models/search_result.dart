import 'video_info.dart';

/// 搜索结果数据模型
class SearchResult {
  final String id;
  final String title;
  final String poster;
  final List<String> episodes;
  final List<String> episodesTitles;
  final String source;
  final String sourceName;
  final String? class_;
  final String year;
  final String? desc;
  final String? typeName;
  final int? doubanId;

  SearchResult({
    required this.id,
    required this.title,
    required this.poster,
    required this.episodes,
    required this.episodesTitles,
    required this.source,
    required this.sourceName,
    this.class_,
    required this.year,
    this.desc,
    this.typeName,
    this.doubanId,
  });

  /// 从JSON创建SearchResult。
  ///
  /// 采集站的 id / 年份 / 豆瓣 id 有时是数字，有时是字符串。类型不一致时如果直接
  /// 赋值，整页搜索结果会解析失败，播放页就会显示「未找到匹配结果」。
  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: _asString(json['id']),
      title: _asString(json['title']),
      poster: _asString(json['poster']),
      episodes: _asStringList(json['episodes']),
      episodesTitles: _asStringList(json['episodes_titles']),
      source: _asString(json['source']),
      sourceName: _asString(json['source_name']),
      class_: _asOptionalString(json['class']),
      year: _asString(json['year']),
      desc: _asOptionalString(json['desc']),
      typeName: _asOptionalString(json['type_name']),
      doubanId: _asInt(json['douban_id']),
    );
  }

  static String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is int) {
      return value.toString();
    }
    if (value is num && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  static String? _asOptionalString(dynamic value) {
    if (value == null) {
      return null;
    }
    return _asString(value);
  }

  static int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return int.tryParse(trimmed);
    }
    return null;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    final items = <String>[];
    for (final item in value) {
      if (item == null) {
        continue;
      }
      if (item is Map) {
        final playUrl = item['playUrl'] ?? item['url'];
        if (playUrl != null && playUrl.toString().isNotEmpty) {
          items.add(playUrl.toString());
        }
        continue;
      }
      final text = _asString(item);
      if (text.isNotEmpty) {
        items.add(text);
      }
    }
    return items;
  }

  /// 跳过无法解析的单条记录，避免一条脏数据让整次详情查询变成空列表。
  static List<SearchResult> parseList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    final parsed = <SearchResult>[];
    for (final item in value) {
      if (item is! Map) {
        continue;
      }
      try {
        parsed.add(SearchResult.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        continue;
      }
    }
    return parsed;
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster': poster,
      'episodes': episodes,
      'episodes_titles': episodesTitles,
      'source': source,
      'source_name': sourceName,
      'class': class_,
      'year': year,
      'desc': desc,
      'type_name': typeName,
      'douban_id': doubanId,
    };
  }

  /// 获取显示用的类型名称
  String get displayType {
    return typeName ?? class_ ?? '未知';
  }

  /// 获取集数信息
  String get episodeInfo {
    if (episodes.isEmpty) return '';
    return '共${episodes.length}集';
  }

  /// 获取年份信息
  String get yearInfo {
    return year.isNotEmpty ? year : '未知年份';
  }

  /// 转换为VideoInfo
  VideoInfo toVideoInfo() {
    return VideoInfo(
      id: id,
      source: source,
      title: title,
      sourceName: sourceName,
      year: year,
      cover: poster,
      index: 1, // 搜索结果默认从第1集开始
      totalEpisodes: episodes.length,
      playTime: 0, // 搜索结果默认未播放
      totalTime: 0, // 搜索结果默认未知总时长
      saveTime: DateTime.now().millisecondsSinceEpoch ~/ 1000, // 当前时间戳
      searchTitle: title, // 使用标题作为搜索标题
      doubanId: doubanId?.toString(), // 传递豆瓣ID，转换为字符串
    );
  }
}

/// WebSocket 搜索事件类型
enum SearchEventType {
  start,
  sourceResult,
  sourceError,
  complete,
}

/// WebSocket 搜索事件基类
abstract class SearchEvent {
  final SearchEventType type;
  final int timestamp;

  SearchEvent({
    required this.type,
    required this.timestamp,
  });

  factory SearchEvent.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String?;
    
    switch (typeString) {
      case 'start':
        return SearchStartEvent.fromJson(json);
      case 'source_result':
        return SearchSourceResultEvent.fromJson(json);
      case 'source_error':
        return SearchSourceErrorEvent.fromJson(json);
      case 'complete':
        return SearchCompleteEvent.fromJson(json);
      default:
        throw Exception('未知的搜索事件类型: $typeString');
    }
  }
}

/// 搜索开始事件
class SearchStartEvent extends SearchEvent {
  final String query;
  final int totalSources;

  SearchStartEvent({
    required this.query,
    required this.totalSources,
    required int timestamp,
  }) : super(
          type: SearchEventType.start,
          timestamp: timestamp,
        );

  factory SearchStartEvent.fromJson(Map<String, dynamic> json) {
    return SearchStartEvent(
      query: json['query'] ?? '',
      totalSources: json['totalSources'] ?? 0,
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// 搜索结果事件
class SearchSourceResultEvent extends SearchEvent {
  final String source;
  final String sourceName;
  final List<SearchResult> results;

  SearchSourceResultEvent({
    required this.source,
    required this.sourceName,
    required this.results,
    required int timestamp,
  }) : super(
          type: SearchEventType.sourceResult,
          timestamp: timestamp,
        );

  factory SearchSourceResultEvent.fromJson(Map<String, dynamic> json) {
    final resultsData = json['results'] as List<dynamic>? ?? [];
    final results = resultsData
        .map((item) => SearchResult.fromJson(item as Map<String, dynamic>))
        .toList();

    return SearchSourceResultEvent(
      source: json['source'] ?? '',
      sourceName: json['sourceName'] ?? '',
      results: results,
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// 搜索错误事件
class SearchSourceErrorEvent extends SearchEvent {
  final String source;
  final String sourceName;
  final String error;

  SearchSourceErrorEvent({
    required this.source,
    required this.sourceName,
    required this.error,
    required int timestamp,
  }) : super(
          type: SearchEventType.sourceError,
          timestamp: timestamp,
        );

  factory SearchSourceErrorEvent.fromJson(Map<String, dynamic> json) {
    return SearchSourceErrorEvent(
      source: json['source'] ?? '',
      sourceName: json['sourceName'] ?? '',
      error: json['error'] ?? '未知错误',
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// 搜索完成事件
class SearchCompleteEvent extends SearchEvent {
  final int totalResults;
  final int completedSources;

  SearchCompleteEvent({
    required this.totalResults,
    required this.completedSources,
    required int timestamp,
  }) : super(
          type: SearchEventType.complete,
          timestamp: timestamp,
        );

  factory SearchCompleteEvent.fromJson(Map<String, dynamic> json) {
    return SearchCompleteEvent(
      totalResults: json['totalResults'] ?? 0,
      completedSources: json['completedSources'] ?? 0,
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
