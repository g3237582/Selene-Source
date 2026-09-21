import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/book.dart';
import 'package:selene/services/books_service.dart';
import 'package:selene/utils/book_catalog.dart';

void main() {
  const chapterBook = BookItem(
    id: '42',
    sourceId: 'legado-a',
    sourceName: '书源A',
    sourceType: 'legado',
    title: '三体',
    author: '刘慈欣',
    detailHref: 'https://book.example/book/42',
    format: 'chapters',
  );

  const gutenbergJson = {
    'id': 'urn:gutenberg:25329',
    'bookId': '25329',
    'title': '朝花夕拾',
    'author': 'Lu, Xun',
    'sourceId': 'gutenberg-zh',
    'sourceName': '古腾堡中文',
    'type': 'opds',
    'detailHref': 'https://www.gutenberg.org/ebooks/25329.opds',
    'bookUrl': 'https://www.gutenberg.org/ebooks/25329.opds',
    'acquisitionLinks': [
      {
        'rel': 'http://opds-spec.org/acquisition',
        'type': 'application/epub+zip',
        'href': 'https://www.gutenberg.org/ebooks/25329.epub.images',
      },
    ],
  };

  group('isListableBookItem', () {
    test('keeps Legado chapter books that can open a directory', () {
      expect(isListableBookItem(chapterBook), isTrue);
      expect(isReadableBookItem(chapterBook), isTrue);
    });

    test('hides catalog nav cards that are not books', () {
      expect(
        isListableBookItem(
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

    test('keeps OPDS / EPUB books that have an acquisition href', () {
      final item = BookItem.fromJson(gutenbergJson);

      expect(item.format, 'epub');
      expect(item.sourceType, 'opds');
      expect(item.acquisitionHref, isNotEmpty);
      expect(isFileStyleBook(item), isTrue);
      expect(isReadableBookItem(item), isTrue);
      expect(kBookFileStreamReaderEnabled, isTrue);
      expect(isListableBookItem(item), isTrue);
    });

    test('hides OPDS-typed cards that have no file hint and no reader path', () {
      final unlabeled = BookItem.fromJson(const {
        'id': '25329',
        'title': '朝花夕拾',
        'detailHref': 'https://www.gutenberg.org/ebooks/25329.opds',
      });
      const source = BookSource(
        id: 'gutenberg-zh',
        name: '古腾堡中文',
        type: 'opds',
        catalogSupported: true,
      );

      final labeled = BooksService.attachSource([unlabeled], source).single;
      expect(labeled.format, 'chapters');
      expect(labeled.sourceType, 'opds');
      expect(hasUsableBookFileHint(labeled), isFalse);
      expect(isListableBookItem(unlabeled), isTrue);
      expect(isListableBookItem(labeled), isFalse);
    });

    test('hides books marked chaptersSupported=false when they have no file hint', () {
      final item = BookItem.fromJson(const {
        'id': '99',
        'title': '空目录',
        'type': 'legado',
        'detailHref': 'https://book.example/book/99',
        'chaptersSupported': false,
      });

      expect(item.chaptersSupported, isFalse);
      expect(isFileStyleBook(item), isFalse);
      expect(isListableBookItem(item), isFalse);
    });

    test('keeps chaptersSupported=false books when a file hint exists', () {
      final item = BookItem.fromJson(const {
        'id': '99',
        'title': '整本文件',
        'type': 'legado',
        'detailHref': 'https://book.example/book/99',
        'chaptersSupported': false,
        'acquisitionHint': '/api/books/file',
        'manifestHint': '/api/books/read/manifest',
      });

      expect(item.chaptersSupported, isFalse);
      expect(isListableBookItem(item), isTrue);
    });

    test('hides PDF file books that have no acquisition or manifest hint', () {
      expect(
        isListableBookItem(
          const BookItem(
            id: '1',
            sourceId: 'wol',
            sourceName: 'Wol.moe',
            sourceType: 'opds',
            title: 'Sample PDF',
            detailHref: 'https://opds.example/book/1',
            format: 'pdf',
          ),
        ),
        isFalse,
      );
    });

    test('treats bookProvider=epub without hints as unlistable', () {
      final item = BookItem.fromJson(const {
        'id': '1',
        'title': 'EPUB only',
        'bookProvider': 'epub',
        'detailHref': 'https://opds.example/book/1',
      });

      expect(item.sourceType, 'epub');
      expect(isFileStyleBook(item), isTrue);
      expect(isListableBookItem(item), isFalse);
    });

    test('keeps EPUB items when the file reader is on and a hint exists', () {
      final item = BookItem.fromJson(gutenbergJson);

      expect(isListableBookItem(item), isTrue);
      expect(
        isListableBookItem(
          item.copyWith(acquisitionHref: '', acquisitionHint: '', manifestHint: ''),
        ),
        isFalse,
      );
      expect(
        isListableBookItem(item, fileStreamReaderEnabled: false),
        isFalse,
      );
    });
  });

  group('listableBookItems', () {
    test('keeps openable file books and drops truly chapter-less cards', () {
      final gutenberg = BookItem.fromJson(gutenbergJson);
      final unsupported = BookItem.fromJson(const {
        'id': '99',
        'title': '空目录',
        'type': 'legado',
        'detailHref': 'https://book.example/book/99',
        'chaptersSupported': false,
      });
      const nav = BookItem(
        id: 'nav',
        sourceId: 'wol',
        sourceName: 'Wol',
        title: '反馈',
      );

      expect(
        listableBookItems([chapterBook, gutenberg, unsupported, nav])
            .map((item) => item.title),
        ['三体', '朝花夕拾'],
      );
    });
  });

  group('BookItem listability fields', () {
    test('fromJson keeps acquisitionHint / manifestHint from the list payload', () {
      final item = BookItem.fromJson({
        ...gutenbergJson,
        'acquisitionHint': '/api/books/file',
        'manifestHint': '/api/books/read/manifest',
      });

      expect(item.acquisitionHint, '/api/books/file');
      expect(item.manifestHint, '/api/books/read/manifest');
      expect(
        item.acquisitionHref,
        'https://www.gutenberg.org/ebooks/25329.epub.images',
      );
    });

    test('fromJson falls back to the first acquisition link as acquisitionHref', () {
      final item = BookItem.fromJson(gutenbergJson);
      expect(
        item.acquisitionHref,
        'https://www.gutenberg.org/ebooks/25329.epub.images',
      );
    });

    test('merge and withSource keep listability fields', () {
      final local = BookItem.fromJson(gutenbergJson);
      const remote = BookItem(
        id: '25329',
        sourceId: 'gutenberg-zh',
        sourceName: '古腾堡中文',
        sourceType: 'opds',
        title: '朝花夕拾',
        detailHref: 'https://www.gutenberg.org/ebooks/25329.opds',
        format: 'epub',
        chaptersSupported: false,
        acquisitionHref: 'https://cdn.example/book.epub',
        acquisitionHint: '/api/books/file',
        manifestHint: '/api/books/read/manifest',
      );

      final merged = mergeBookDetail(remote, local);
      expect(merged.chaptersSupported, isFalse);
      expect(merged.acquisitionHref, 'https://cdn.example/book.epub');
      expect(merged.acquisitionHint, '/api/books/file');
      expect(merged.manifestHint, '/api/books/read/manifest');

      final labeled = local.withSource(
        const BookSource(id: 'gutenberg-zh', name: '古腾堡中文', type: 'opds'),
      );
      expect(labeled.acquisitionHref, local.acquisitionHref);
      expect(labeled.format, 'epub');
    });
  });
}
