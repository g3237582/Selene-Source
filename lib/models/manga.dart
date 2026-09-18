class MangaSource {
  final String id;
  final String name;
  final String lang;

  const MangaSource({
    required this.id,
    required this.name,
    this.lang = '',
  });

  factory MangaSource.fromJson(Map<String, dynamic> json) {
    return MangaSource(
      id: json['id']?.toString() ?? '',
      name: (json['displayName'] ?? json['name'] ?? '').toString(),
      lang: json['lang']?.toString() ?? '',
    );
  }
}

class MangaItem {
  final String id;
  final String sourceId;
  final String sourceName;
  final String title;
  final String cover;
  final String description;
  final String author;
  final String status;

  const MangaItem({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.title,
    required this.cover,
    this.description = '',
    this.author = '',
    this.status = '',
  });

  factory MangaItem.fromJson(Map<String, dynamic> json) {
    return MangaItem(
      id: json['id']?.toString() ?? json['mangaId']?.toString() ?? '',
      sourceId: json['sourceId']?.toString() ?? '',
      sourceName: json['sourceName']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }

  String get shelfKey => '$sourceId+$id';
}

class MangaChapter {
  final String id;
  final String mangaId;
  final String name;
  final int pageCount;

  const MangaChapter({
    required this.id,
    required this.mangaId,
    required this.name,
    this.pageCount = 0,
  });

  factory MangaChapter.fromJson(Map<String, dynamic> json) {
    return MangaChapter(
      id: json['id']?.toString() ?? '',
      mangaId: json['mangaId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      pageCount: json['pageCount'] is int
          ? json['pageCount'] as int
          : int.tryParse(json['pageCount']?.toString() ?? '') ?? 0,
    );
  }
}

class MangaDetail extends MangaItem {
  final List<MangaChapter> chapters;

  const MangaDetail({
    required super.id,
    required super.sourceId,
    required super.sourceName,
    required super.title,
    required super.cover,
    super.description,
    super.author,
    super.status,
    required this.chapters,
  });

  factory MangaDetail.fromJson(Map<String, dynamic> json) {
    final item = MangaItem.fromJson(json);
    final chapters = (json['chapters'] as List? ?? [])
        .whereType<Map>()
        .map((chapter) => MangaChapter.fromJson(Map<String, dynamic>.from(chapter)))
        .toList();
    return MangaDetail(
      id: item.id,
      sourceId: item.sourceId,
      sourceName: item.sourceName,
      title: item.title,
      cover: item.cover,
      description: item.description,
      author: item.author,
      status: item.status,
      chapters: chapters,
    );
  }
}

class MangaShelfItem {
  final String title;
  final String cover;
  final String sourceId;
  final String sourceName;
  final String mangaId;
  final String lastChapterName;

  const MangaShelfItem({
    required this.title,
    required this.cover,
    required this.sourceId,
    required this.sourceName,
    required this.mangaId,
    this.lastChapterName = '',
  });

  factory MangaShelfItem.fromJson(Map<String, dynamic> json) {
    return MangaShelfItem(
      title: json['title']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      sourceId: json['sourceId']?.toString() ?? '',
      sourceName: json['sourceName']?.toString() ?? '',
      mangaId: json['mangaId']?.toString() ?? '',
      lastChapterName:
          (json['lastChapterName'] ?? json['latestChapterName'] ?? '')
              .toString(),
    );
  }

  MangaItem toItem() {
    return MangaItem(
      id: mangaId,
      sourceId: sourceId,
      sourceName: sourceName,
      title: title,
      cover: cover,
    );
  }
}

class MangaReadRecord {
  final String title;
  final String cover;
  final String sourceId;
  final String sourceName;
  final String mangaId;
  final String chapterId;
  final String chapterName;
  final int pageIndex;
  final int pageCount;

  const MangaReadRecord({
    required this.title,
    required this.cover,
    required this.sourceId,
    required this.sourceName,
    required this.mangaId,
    required this.chapterId,
    required this.chapterName,
    this.pageIndex = 0,
    this.pageCount = 0,
  });

  factory MangaReadRecord.fromJson(Map<String, dynamic> json) {
    return MangaReadRecord(
      title: json['title']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      sourceId: json['sourceId']?.toString() ?? '',
      sourceName: json['sourceName']?.toString() ?? '',
      mangaId: json['mangaId']?.toString() ?? '',
      chapterId: json['chapterId']?.toString() ?? '',
      chapterName: json['chapterName']?.toString() ?? '',
      pageIndex: json['pageIndex'] is int
          ? json['pageIndex'] as int
          : int.tryParse(json['pageIndex']?.toString() ?? '') ?? 0,
      pageCount: json['pageCount'] is int
          ? json['pageCount'] as int
          : int.tryParse(json['pageCount']?.toString() ?? '') ?? 0,
    );
  }

  MangaItem toItem() {
    return MangaItem(
      id: mangaId,
      sourceId: sourceId,
      sourceName: sourceName,
      title: title,
      cover: cover,
    );
  }
}
