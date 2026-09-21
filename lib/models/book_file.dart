import 'book.dart';

class BookChaptersNotApplicable {
  static const notApplicableCode = 'chapters_not_applicable';
  static const defaultAcquisitionHint = '/api/books/file';
  static const defaultManifestHint = '/api/books/read/manifest';

  final String error;
  final String code;
  final String sourceType;
  final String format;
  final String acquisitionHint;
  final String manifestHint;

  const BookChaptersNotApplicable({
    required this.error,
    this.code = notApplicableCode,
    this.sourceType = 'opds',
    this.format = 'epub',
    this.acquisitionHint = defaultAcquisitionHint,
    this.manifestHint = defaultManifestHint,
  });

  bool get isEpub => format.toLowerCase() == 'epub';

  factory BookChaptersNotApplicable.defaults({String format = 'epub'}) {
    return BookChaptersNotApplicable(
      error: '当前书源为文件/OPDS 资源，章节目录接口不适用。',
      format: _normalizeFormat(format),
    );
  }

  static BookChaptersNotApplicable? tryParse(
    Object? body, {
    int? statusCode,
  }) {
    if (body is! Map) {
      return null;
    }
    final json = Map<String, dynamic>.from(body);
    final rawCode = firstNonEmptyString([json['code']]).toLowerCase();
    final hasCode =
        rawCode == notApplicableCode || rawCode == 'chapters-not-applicable';
    final acquisitionHint = firstNonEmptyString([
      json['acquisitionHint'],
      json['acquisition_hint'],
    ]);
    final manifestHint = firstNonEmptyString([
      json['manifestHint'],
      json['manifest_hint'],
    ]);
    final hasHints = acquisitionHint.isNotEmpty && manifestHint.isNotEmpty;
    if (!hasCode && !(statusCode == 422 && hasHints)) {
      return null;
    }
    return BookChaptersNotApplicable(
      error: firstNonEmptyString(
        [json['error'], json['message']],
        fallback: '当前书源为文件/OPDS 资源，章节目录接口不适用。',
      ),
      code: notApplicableCode,
      sourceType: firstNonEmptyString(
        [json['sourceType'], json['source_type']],
        fallback: 'opds',
      ),
      format: _normalizeFormat(
        firstNonEmptyString([json['format']], fallback: 'epub'),
      ),
      acquisitionHint: _normalizeHint(
        acquisitionHint,
        fallback: defaultAcquisitionHint,
      ),
      manifestHint: _normalizeHint(
        manifestHint,
        fallback: defaultManifestHint,
      ),
    );
  }
}

class BookChaptersNotApplicableException implements Exception {
  final BookChaptersNotApplicable payload;

  const BookChaptersNotApplicableException(this.payload);

  @override
  String toString() => payload.error;
}

class BookReadManifest {
  final BookItem book;
  final String format;
  final String fileUrl;
  final String acquisitionHref;
  final String cacheKey;

  const BookReadManifest({
    required this.book,
    this.format = 'epub',
    this.fileUrl = '',
    this.acquisitionHref = '',
    this.cacheKey = '',
  });

  factory BookReadManifest.fromJson(Map<String, dynamic> json) {
    final bookJson = json['book'] is Map
        ? Map<String, dynamic>.from(json['book'] as Map)
        : json;
    final book = BookItem.fromJson(bookJson);
    final acquisitionHref = firstNonEmptyString([
      json['acquisitionHref'],
      json['acquisition_href'],
      book.acquisitionHref,
    ]);
    return BookReadManifest(
      book: book.acquisitionHref.isEmpty && acquisitionHref.isNotEmpty
          ? book.copyWith(acquisitionHref: acquisitionHref)
          : book,
      format: _normalizeFormat(
        firstNonEmptyString([json['format'], book.format], fallback: 'epub'),
      ),
      fileUrl: firstNonEmptyString([json['fileUrl'], json['file_url']]),
      acquisitionHref: acquisitionHref,
      cacheKey: firstNonEmptyString([json['cacheKey'], json['cache_key']]),
    );
  }
}

class BookFileOpenPlan {
  final String fileEndpoint;
  final String manifestEndpoint;
  final String fileUrl;
  final Map<String, dynamic> fileBody;
  final Map<String, dynamic> manifestBody;
  final String format;
  final bool preferInAppReader;

  const BookFileOpenPlan({
    required this.fileEndpoint,
    required this.manifestEndpoint,
    required this.fileBody,
    required this.manifestBody,
    this.fileUrl = '',
    this.format = 'epub',
    this.preferInAppReader = true,
  });

  factory BookFileOpenPlan.from({
    required BookItem book,
    required BookChaptersNotApplicable hints,
    BookReadManifest? manifest,
  }) {
    final format = _normalizeFormat(
      firstNonEmptyString(
        [manifest?.format, hints.format, book.format],
        fallback: 'epub',
      ),
    );
    final acquisitionHref = firstNonEmptyString([
      manifest?.acquisitionHref,
      book.acquisitionHref,
    ]);
    final locator = firstNonEmptyString([
      if (isBookDetailHref(book.detailHref)) book.detailHref,
      resolveBookDetailLocator(book),
    ]);
    return BookFileOpenPlan(
      fileEndpoint: _normalizeHint(
        hints.acquisitionHint,
        fallback: BookChaptersNotApplicable.defaultAcquisitionHint,
      ),
      manifestEndpoint: _normalizeHint(
        hints.manifestHint,
        fallback: BookChaptersNotApplicable.defaultManifestHint,
      ),
      fileUrl: manifest?.fileUrl ?? '',
      format: format,
      preferInAppReader: format == 'epub',
      fileBody: {
        'sourceId': book.sourceId,
        if (book.id.isNotEmpty) 'bookId': book.id,
        if (acquisitionHref.isNotEmpty) 'href': acquisitionHref,
        if (format.isNotEmpty) 'format': format,
      },
      manifestBody: {
        'sourceId': book.sourceId,
        if (book.id.isNotEmpty) 'bookId': book.id,
        if (locator.isNotEmpty) 'href': locator,
        if (acquisitionHref.isNotEmpty) 'acquisitionHref': acquisitionHref,
        if (format.isNotEmpty) 'format': format,
        if (book.title.isNotEmpty) 'title': book.title,
        if (book.author.isNotEmpty) 'author': book.author,
        if (book.cover.isNotEmpty) 'cover': book.cover,
        if (book.summary.isNotEmpty) 'summary': book.summary,
      },
    );
  }
}

String _normalizeFormat(String format) {
  final value = format.trim().toLowerCase();
  if (value == 'pdf') {
    return 'pdf';
  }
  if (value == 'chapters') {
    return 'chapters';
  }
  return 'epub';
}

String _normalizeHint(String hint, {required String fallback}) {
  final value = hint.trim();
  if (value.isEmpty) {
    return fallback;
  }
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    final path = uri.path.isEmpty ? fallback : uri.path;
    return path.startsWith('/') ? path : '/$path';
  }
  return value.startsWith('/') ? value : '/$value';
}
