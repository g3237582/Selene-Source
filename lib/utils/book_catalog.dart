import '../models/book.dart';

bool isReadableBookItem(BookItem item) {
  return isBookDetailHref(item.detailHref) || isBookDetailHref(item.id);
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
    title: firstNonEmptyString([remote.title, local.title]),
    author: firstNonEmptyString([remote.author, local.author]),
    cover: firstNonEmptyString([remote.cover, local.cover]),
    summary: firstNonEmptyString([remote.summary, local.summary]),
    detailHref: detailHref,
    format: firstNonEmptyString(
      [remote.format, local.format],
      fallback: 'chapters',
    ),
  );
}

String bookEmptyChaptersMessage(BookItem book) {
  final format = book.format.toLowerCase();
  if (format == 'epub' || format == 'pdf') {
    return '该书暂不支持章节阅读。EPUB 文件流会在后续版本接入。';
  }
  return '该书没有章节资源';
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
