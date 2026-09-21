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
  final String acquisitionHref;
  final bool? chaptersSupported;
  final String acquisitionHint;
  final String manifestHint;

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
    this.acquisitionHref = '',
    this.chaptersSupported,
    this.acquisitionHint = '',
    this.manifestHint = '',
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
      title: preferredBookTitle([json['title'], json['name']]),
      author: firstNonEmptyString([json['author']]),
      cover: firstNonEmptyString([json['cover']]),
      summary: firstNonEmptyString([json['summary']]),
      detailHref: detailHref,
      format: firstNonEmptyString(
        [json['format'], acquisition.format],
        fallback: 'chapters',
      ),
      acquisitionHref: firstNonEmptyString([
        json['acquisitionHref'],
        json['acquisition_href'],
        acquisition.href,
      ]),
      chaptersSupported: optionalBool(json['chaptersSupported']),
      acquisitionHint: firstNonEmptyString([
        json['acquisitionHint'],
        json['acquisition_hint'],
      ]),
      manifestHint: firstNonEmptyString([
        json['manifestHint'],
        json['manifest_hint'],
      ]),
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
    return copyWith(
      sourceId: resolvedId,
      sourceName: resolvedName,
      sourceType: resolvedType,
    );
  }

  BookItem copyWith({
    String? id,
    String? sourceId,
    String? sourceName,
    String? sourceType,
    String? title,
    String? author,
    String? cover,
    String? summary,
    String? detailHref,
    String? format,
    String? acquisitionHref,
    bool? chaptersSupported,
    String? acquisitionHint,
    String? manifestHint,
  }) {
    return BookItem(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      sourceType: sourceType ?? this.sourceType,
      title: title ?? this.title,
      author: author ?? this.author,
      cover: cover ?? this.cover,
      summary: summary ?? this.summary,
      detailHref: detailHref ?? this.detailHref,
      format: format ?? this.format,
      acquisitionHref: acquisitionHref ?? this.acquisitionHref,
      chaptersSupported: chaptersSupported ?? this.chaptersSupported,
      acquisitionHint: acquisitionHint ?? this.acquisitionHint,
      manifestHint: manifestHint ?? this.manifestHint,
    );
  }
}

bool isPlaceholderBookTitle(String? title) {
  final text = title?.trim() ?? '';
  if (text.isEmpty) {
    return true;
  }
  return text == '未命名电子书' ||
      text == '未命名' ||
      text.toLowerCase() == 'untitled';
}

String preferredBookTitle(Iterable<Object?> values) {
  var placeholder = '';
  for (final value in values) {
    final text = firstNonEmptyString([value]);
    if (text.isEmpty) {
      continue;
    }
    if (!isPlaceholderBookTitle(text)) {
      return text;
    }
    if (placeholder.isEmpty) {
      placeholder = text;
    }
  }
  return placeholder;
}

String _sourceTypeFromJson(Map<String, dynamic> json) {
  final explicit = firstNonEmptyString([json['sourceType']]);
  if (explicit.isNotEmpty) {
    return explicit;
  }
  final type = firstNonEmptyString([
    json['type'],
    json['bookProvider'],
  ]).toLowerCase();
  return type == 'opds' || type == 'legado' || type == 'epub' ? type : '';
}

bool? optionalBool(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') {
    return true;
  }
  if (text == 'false' || text == '0') {
    return false;
  }
  return null;
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
