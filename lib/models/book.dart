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
  final String sourceType;
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
    this.sourceType = '',
    this.author = '',
    this.cover = '',
    this.summary = '',
    this.detailHref = '',
    this.format = 'chapters',
  });

  factory BookItem.fromJson(Map<String, dynamic> json) {
    final acquisition = _firstAcquisition(json);
    final rawHref = firstNonEmptyString([
      json['detailHref'],
      json['bookUrl'],
      json['href'],
      acquisition.href,
    ]);
    final detailHref = isBookDetailHref(rawHref) ? rawHref : '';
    return BookItem(
      id: firstNonEmptyString([
        json['bookId'],
        json['id'],
        detailHref,
      ]),
      sourceId: firstNonEmptyString([json['sourceId']]),
      sourceName: firstNonEmptyString([json['sourceName']]),
      sourceType: _sourceTypeFromJson(json),
      title: firstNonEmptyString([json['title']]),
      author: firstNonEmptyString([json['author']]),
      cover: firstNonEmptyString([json['cover']]),
      summary: firstNonEmptyString([json['summary']]),
      detailHref: detailHref,
      format: firstNonEmptyString(
        [json['format'], acquisition.format],
        fallback: 'chapters',
      ),
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
    final resolvedType = sourceType.isEmpty ? source.type : sourceType;
    if (resolvedId == sourceId &&
        resolvedName == sourceName &&
        resolvedType == sourceType) {
      return this;
    }
    return BookItem(
      id: id,
      sourceId: resolvedId,
      sourceName: resolvedName,
      sourceType: resolvedType,
      title: title,
      author: author,
      cover: cover,
      summary: summary,
      detailHref: detailHref,
      format: format,
    );
  }
}

String _sourceTypeFromJson(Map<String, dynamic> json) {
  final explicit = firstNonEmptyString([json['sourceType']]);
  if (explicit.isNotEmpty) {
    return explicit;
  }
  final type = firstNonEmptyString([json['type']]).toLowerCase();
  return type == 'opds' || type == 'legado' ? type : '';
}

String firstNonEmptyString(
  Iterable<Object?> values, {
  String fallback = '',
}) {
  for (final value in values) {
    if (value == null) {
      continue;
    }
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') {
      continue;
    }
    return text;
  }
  return fallback;
}

bool isCatalogCursor(String value) {
  final href = value.trim();
  return href.startsWith('legado-explore:') ||
      href.startsWith('legado:explore') ||
      href.startsWith('__group__:');
}

bool isBookDetailHref(String value) {
  final href = value.trim();
  if (href.isEmpty || isCatalogCursor(href)) {
    return false;
  }
  final lower = href.toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      href.startsWith('/');
}

/// Locator the books detail/chapters APIs can resolve.
/// Prefer a bookUrl / detail href over a catalog JSON id.
String resolveBookDetailLocator(BookItem book) {
  if (isBookDetailHref(book.detailHref)) {
    return book.detailHref.trim();
  }
  if (isBookDetailHref(book.id)) {
    return book.id.trim();
  }
  final id = book.id.trim();
  if (id.isEmpty || isCatalogCursor(id)) {
    return '';
  }
  return id;
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
