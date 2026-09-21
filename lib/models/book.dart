class BookSource {
  final String id;
  final String name;
  final String type;
  final bool searchSupported;
  final bool catalogSupported;

  const BookSource({
    required this.id,
    required this.name,
    this.type = '',
    this.searchSupported = true,
    this.catalogSupported = false,
  });

  factory BookSource.fromJson(Map<String, dynamic> json) {
    final capabilities = json['capabilities'] is Map
        ? Map<String, dynamic>.from(json['capabilities'] as Map)
        : const <String, dynamic>{};
    return BookSource(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      searchSupported: capabilities['searchSupported'] != false,
      catalogSupported: capabilities['catalogSupported'] == true,
    );
  }
}

class BookItem {
  final String id;
  final String sourceId;
  final String sourceName;
  final String title;
  final String author;
  final String cover;
  final String summary;
  final String detailHref;
  final String format;

  const BookItem({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.title,
    this.author = '',
    this.cover = '',
    this.summary = '',
    this.detailHref = '',
    this.format = 'chapters',
  });

  factory BookItem.fromJson(Map<String, dynamic> json) {
    final acquisition = _firstAcquisition(json);
    return BookItem(
      id: json['id']?.toString() ?? json['bookId']?.toString() ?? '',
      sourceId: json['sourceId']?.toString() ?? '',
      sourceName: json['sourceName']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      detailHref: (json['detailHref'] ?? json['href'] ?? acquisition.href)
          .toString(),
      format: json['format']?.toString().isNotEmpty == true
          ? json['format'].toString()
          : acquisition.format,
    );
  }

  static ({String href, String format}) _firstAcquisition(
    Map<String, dynamic> json,
  ) {
    final links = json['acquisitionLinks'];
    if (links is! List) {
      return (href: '', format: 'chapters');
    }
    for (final item in links.whereType<Map>()) {
      final href = item['href']?.toString() ?? '';
      if (href.isEmpty) continue;
      final type = item['type']?.toString().toLowerCase() ?? '';
      final format = type.contains('pdf')
          ? 'pdf'
          : type.contains('epub')
          ? 'epub'
          : 'chapters';
      return (href: href, format: format);
    }
    return (href: '', format: 'chapters');
  }

  String get shelfKey => '$sourceId+$id';

  BookItem withSource(BookSource source) {
    final resolvedId = sourceId.isEmpty ? source.id : sourceId;
    final resolvedName = sourceName.isEmpty ? source.name : sourceName;
    if (resolvedId == sourceId && resolvedName == sourceName) {
      return this;
    }
    return BookItem(
      id: id,
      sourceId: resolvedId,
      sourceName: resolvedName,
      title: title,
      author: author,
      cover: cover,
      summary: summary,
      detailHref: detailHref,
      format: format,
    );
  }
}

class BookNavLink {
  final String title;
  final String href;
  final String rel;

  const BookNavLink({
    required this.title,
    required this.href,
    this.rel = '',
  });

  factory BookNavLink.fromJson(Map<String, dynamic> json) {
    return BookNavLink(
      title: json['title']?.toString() ?? '',
      href: json['href']?.toString() ?? '',
      rel: json['rel']?.toString() ?? '',
    );
  }
}

class BookCatalog {
  final List<BookItem> entries;
  final List<BookNavLink> navigation;
  final String nextHref;

  const BookCatalog({
    this.entries = const [],
    this.navigation = const [],
    this.nextHref = '',
  });
}

class BookChapter {
  final String id;
  final String title;
  final String href;
  final int order;

  const BookChapter({
    required this.id,
    required this.title,
    required this.href,
    this.order = 0,
  });

  factory BookChapter.fromJson(Map<String, dynamic> json) {
    return BookChapter(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      href: json['href']?.toString() ?? '',
      order: json['order'] is int
          ? json['order'] as int
          : int.tryParse(json['order']?.toString() ?? '') ?? 0,
    );
  }
}

class BookChapterContent {
  final String id;
  final String title;
  final String href;
  final String content;
  final String nextHref;
  final String previousHref;

  const BookChapterContent({
    required this.id,
    required this.title,
    required this.href,
    required this.content,
    this.nextHref = '',
    this.previousHref = '',
  });

  factory BookChapterContent.fromJson(Map<String, dynamic> json) {
    return BookChapterContent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      href: json['href']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      nextHref: json['nextHref']?.toString() ?? '',
      previousHref: json['previousHref']?.toString() ?? '',
    );
  }
}
