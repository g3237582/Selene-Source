import '../models/book.dart';

bool isReadableBookItem(BookItem item) {
  return item.detailHref.isNotEmpty ||
      item.author.isNotEmpty ||
      item.cover.isNotEmpty;
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
