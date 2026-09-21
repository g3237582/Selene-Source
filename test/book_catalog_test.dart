import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/book.dart';
import 'package:selene/services/books_service.dart';
import 'package:selene/utils/book_catalog.dart';

void main() {
  test('root navigation-only feeds auto-open the latest-update catalog', () {
    final href = resolveDefaultBookCatalogHref(
      entries: const [
        BookItem(
          id: 'nav',
          sourceId: 'wol-zh-cn',
          sourceName: 'Wol.moe',
          title: '反馈群组',
        ),
      ],
      navigation: const [
        BookNavLink(
          title: '总点击榜',
          href: 'https://opds.wol.moe/zh_CN/allVisit.xml',
          rel: 'http://opds-spec.org/sort/popular',
        ),
        BookNavLink(
          title: '最近更新',
          href: 'https://opds.wol.moe/zh_CN/lastUpdate.xml',
          rel: 'http://opds-spec.org/sort/new',
        ),
      ],
    );
    expect(href, 'https://opds.wol.moe/zh_CN/lastUpdate.xml');
  });

  test('feeds that already contain books stay on the current page', () {
    final href = resolveDefaultBookCatalogHref(
      entries: const [
        BookItem(
          id: '1',
          sourceId: 'wol-zh-cn',
          sourceName: 'Wol.moe',
          title: '三体',
          author: '刘慈欣',
        ),
      ],
      navigation: const [
        BookNavLink(
          title: '最近更新',
          href: 'https://opds.wol.moe/zh_CN/lastUpdate.xml',
          rel: 'http://opds-spec.org/sort/new',
        ),
      ],
    );
    expect(href, isNull);
  });

  test('catalogSources keeps only sources that can browse a home feed', () {
    expect(
      BooksService.catalogSources(const [
        BookSource(id: 'off', name: '关闭', catalogSupported: false),
        BookSource(id: '', name: '空', catalogSupported: true),
        BookSource(id: 'on', name: '可浏览', catalogSupported: true),
        BookSource(id: 'search-only', name: '仅搜索'),
      ]).map((source) => source.id),
      ['on'],
    );
  });

  test('searchableSources keeps only sources that can search', () {
    expect(
      BooksService.searchableSources(const [
        BookSource(id: 'off', name: '关闭', searchSupported: false),
        BookSource(id: '', name: '空'),
        BookSource(id: 'on', name: '可搜'),
      ]).map((source) => source.id),
      ['on'],
    );
  });

  test('catalog entries without author or cover are hidden', () {
    expect(
      isReadableBookItem(
        const BookItem(
          id: 'nav',
          sourceId: 'wol-zh-cn',
          sourceName: 'Wol.moe',
          title: '反馈群组',
        ),
      ),
      isFalse,
    );
  });
}
