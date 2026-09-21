import '../models/book.dart';
import '../models/book_file.dart';

bool isReadableBookItem(BookItem item) {
  return isBookDetailHref(item.detailHref) || isBookDetailHref(item.id);
}

/// The client can open EPUB/PDF via /api/books/file and /api/books/read/manifest.
const bool kBookFileStreamReaderEnabled = true;

/// Books that belong in catalog / recommend / search / home lists.
/// File-style OPDS items stay visible when a file hint exists; chapter-less
/// books without a usable file path stay hidden.
bool isListableBookItem(
  BookItem item, {
  bool fileStreamReaderEnabled = kBookFileStreamReaderEnabled,
}) {
  if (!isReadableBookItem(item)) {
    return false;
  }
  if (isFileStyleBook(item) || item.chaptersSupported == false) {
    return canOpenFileStyleBook(
      item,
      fileStreamReaderEnabled: fileStreamReaderEnabled,
    );
  }
  return true;
}

bool hasUsableBookFileHint(BookItem item) {
  return item.acquisitionHref.trim().isNotEmpty ||
      item.acquisitionHint.trim().isNotEmpty ||
      item.manifestHint.trim().isNotEmpty;
}

bool canOpenFileStyleBook(
  BookItem item, {
  bool fileStreamReaderEnabled = kBookFileStreamReaderEnabled,
}) {
  return fileStreamReaderEnabled && hasUsableBookFileHint(item);
}

List<BookItem> listableBookItems(Iterable<BookItem> items) {
  return [for (final item in items) if (isListableBookItem(item)) item];
}

Map<String, String> bookDetailRequest(BookItem book) {
  final locator = resolveBookDetailLocator(book);
  final href = isBookDetailHref(book.detailHref)
      ? book.detailHref.trim()
      : (isBookDetailHref(locator) ? locator : '');
  return {
    'sourceId': book.sourceId,
    'bookId': locator,
    'href': href,
    'title': book.title,
    'author': book.author,
    'cover': book.cover,
    'summary': book.summary,
  };
}

Map<String, String> bookChaptersQuery(BookItem book) {
  final locator = resolveBookDetailLocator(book);
  final href =
      isBookDetailHref(book.detailHref) ? book.detailHref.trim() : '';
  return {
    'sourceId': book.sourceId,
    if (locator.isNotEmpty) 'bookId': locator,
    if (href.isNotEmpty) 'href': href,
  };
}

BookItem mergeBookDetail(BookItem remote, BookItem local) {
  final detailHref = firstNonEmptyString([
    if (isBookDetailHref(remote.detailHref)) remote.detailHref,
    if (isBookDetailHref(local.detailHref)) local.detailHref,
    remote.detailHref,
    local.detailHref,
  ]);
  return BookItem(
    id: firstNonEmptyString([
      if (isBookDetailHref(remote.id)) remote.id,
      if (isBookDetailHref(local.id)) local.id,
      if (isBookDetailHref(detailHref)) detailHref,
      local.id,
      remote.id,
    ]),
    sourceId: firstNonEmptyString([remote.sourceId, local.sourceId]),
    sourceName: firstNonEmptyString([remote.sourceName, local.sourceName]),
    sourceType: firstNonEmptyString([remote.sourceType, local.sourceType]),
    title: preferredBookTitle([remote.title, local.title]),
    author: firstNonEmptyString([remote.author, local.author]),
    cover: firstNonEmptyString([remote.cover, local.cover]),
    summary: firstNonEmptyString([remote.summary, local.summary]),
    detailHref: detailHref,
    format: firstNonEmptyString(
      [remote.format, local.format],
      fallback: 'chapters',
    ),
    acquisitionHref: firstNonEmptyString([
      remote.acquisitionHref,
      local.acquisitionHref,
    ]),
    chaptersSupported: remote.chaptersSupported ?? local.chaptersSupported,
    acquisitionHint: firstNonEmptyString([
      remote.acquisitionHint,
      local.acquisitionHint,
    ]),
    manifestHint: firstNonEmptyString([
      remote.manifestHint,
      local.manifestHint,
    ]),
  );
}

bool isFileStyleBook(BookItem book) {
  final format = book.format.toLowerCase();
  if (format == 'epub' || format == 'pdf') {
    return true;
  }
  final type = book.sourceType.toLowerCase();
  return type == 'opds' || type == 'epub';
}

bool shouldFetchBookChapters(BookItem book) {
  // Always probe /api/books/read/chapters. OPDS/EPUB sources now return
  // 422 + acquisition/manifest hints instead of a Legado lookup failure.
  return book.sourceId.isNotEmpty || resolveBookDetailLocator(book).isNotEmpty;
}

bool isLegadoSourceMissingError(Object error) {
  return error.toString().contains('未找到对应的 Legado 书源');
}

String bookEmptyChaptersMessage(BookItem book) {
  if (isFileStyleBook(book)) {
    return '这是整本 EPUB/PDF 电子书。打开后将通过文件接口阅读。';
  }
  return '该书没有章节资源';
}

String bookFileBookMessage(BookItem book, {String format = ''}) {
  final resolved = (format.isNotEmpty ? format : book.format).toUpperCase();
  final label = resolved == 'PDF' ? 'PDF' : 'EPUB';
  return '这是整本 $label 电子书，章节目录不适用。请直接阅读或下载文件。';
}

final _upstreamHttpStatus = RegExp(r'请求失败\s*[:：]\s*(\d{3})');

String bookChaptersErrorMessage(Object error, BookItem book) {
  if (error is BookChaptersNotApplicableException) {
    return bookFileBookMessage(book, format: error.payload.format);
  }
  if (isLegadoSourceMissingError(error)) {
    if (isFileStyleBook(book)) {
      return bookEmptyChaptersMessage(book);
    }
    return '当前书源不是可用的章节型 Legado 源，无法拉取目录。请换一个书源，或检查后台书源配置。';
  }
  final status = _upstreamHttpStatus.firstMatch(error.toString())?.group(1);
  if (status == '422') {
    return bookFileBookMessage(book);
  }
  if (status == '403') {
    final source = book.sourceName.isEmpty ? '该书源' : '「${book.sourceName}」';
    return '源站拒绝了章节目录请求（403）。$source 可能需要登录、Cookie 或更新请求头，请换一个书源或检查后台书源规则。';
  }
  if (status == '404') {
    return '源站没有找到章节目录（404）。请换一个书源试试。';
  }
  if (status != null) {
    return '源站返回 $status，暂时无法拉取章节。请换一个书源或稍后重试。';
  }
  return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
}

int bookCatalogNavScore(BookNavLink nav) {
  final rel = nav.rel.toLowerCase();
  final href = nav.href.toLowerCase();
  final title = nav.title;
  if (rel.contains('sort/new') ||
      href.contains('lastupdate') ||
      title.contains('最近更新')) {
    return 3;
  }
  if (rel.contains('sort/popular') ||
      title.contains('排行') ||
      title.contains('点击')) {
    return 2;
  }
  return 1;
}

String? resolveDefaultBookCatalogHref({
  required List<BookItem> entries,
  required List<BookNavLink> navigation,
}) {
  if (entries.any(isReadableBookItem) || navigation.isEmpty) {
    return null;
  }
  final ranked = [...navigation]
    ..sort((left, right) => bookCatalogNavScore(right) - bookCatalogNavScore(left));
  final href = ranked.first.href.trim();
  return href.isEmpty ? null : href;
}
