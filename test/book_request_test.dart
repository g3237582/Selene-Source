import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/book.dart';
import 'package:selene/services/books_service.dart';
import 'package:selene/utils/book_catalog.dart';

void main() {
  group('recommend / search card → detail request', () {
    test('numeric catalog id does not override the bookUrl href', () {
      final item = BookItem.fromJson(const {
        'id': '42',
        'bookId': '42',
        'title': '三体',
        'author': '刘慈欣',
        'cover': 'https://cdn.example/cover.jpg',
        'detailHref': 'https://book.example/book/42',
      });

      expect(resolveBookDetailLocator(item), 'https://book.example/book/42');
      expect(bookDetailRequest(item)['bookId'], 'https://book.example/book/42');
      expect(bookDetailRequest(item)['href'], 'https://book.example/book/42');
      expect(bookChaptersQuery(item)['bookId'], 'https://book.example/book/42');
      expect(bookChaptersQuery(item)['href'], 'https://book.example/book/42');
    });

    test('empty id falls back to bookId then bookUrl', () {
      final item = BookItem.fromJson(const {
        'id': '',
        'bookId': '',
        'href': '',
        'bookUrl': 'https://book.example/santi',
        'title': '三体',
      });

      expect(item.id, 'https://book.example/santi');
      expect(item.detailHref, 'https://book.example/santi');
      expect(bookDetailRequest(item)['bookId'], 'https://book.example/santi');
    });

    test('all-source search cards pick up the queried sourceId', () {
      final unlabeled = BookItem.fromJson(const {
        'id': '99',
        'title': '三体',
        'detailHref': 'https://book.example/book/99',
      });
      const source = BookSource(id: 'legado-a', name: '书源A');

      expect(unlabeled.sourceId, isEmpty);
      final labeled = BooksService.attachSource([unlabeled], source).single;
      expect(bookDetailRequest(labeled)['sourceId'], 'legado-a');
      expect(bookChaptersQuery(labeled)['sourceId'], 'legado-a');
    });

    test('explore catalog tokens are not treated as a book locator', () {
      final item = BookItem.fromJson(const {
        'id': 'nav',
        'title': '玄幻',
        'cover': 'https://cdn.example/xuanhuan.png',
        'href': 'legado-explore:abc',
      });

      expect(item.detailHref, isEmpty);
      expect(isBookDetailHref(item.detailHref), isFalse);
      expect(isReadableBookItem(item), isFalse);
      expect(bookChaptersQuery(item).containsKey('href'), isFalse);
      expect(bookChaptersQuery(item)['bookId'], isNot('legado-explore:abc'));
    });

    test('getDetail keeps the local bookUrl when remote only returns a hash id', () {
      const local = BookItem(
        id: '42',
        sourceId: 'legado-a',
        sourceName: '书源A',
        title: '三体',
        detailHref: 'https://book.example/book/42',
      );
      const remote = BookItem(
        id: 'a1b2c3',
        sourceId: '',
        sourceName: '',
        title: '三体',
        summary: '科幻',
      );

      final merged = mergeBookDetail(remote, local);
      expect(merged.sourceId, 'legado-a');
      expect(merged.detailHref, 'https://book.example/book/42');
      expect(resolveBookDetailLocator(merged), 'https://book.example/book/42');
      expect(merged.summary, '科幻');
    });
  });

  group('empty chapter copy', () {
    test('chapter books say they have no chapter resources', () {
      expect(
        bookEmptyChaptersMessage(
          const BookItem(
            id: '1',
            sourceId: 'legado-a',
            sourceName: '书源A',
            title: '三体',
            format: 'chapters',
          ),
        ),
        '该书没有章节资源',
      );
    });

    test('epub books keep the upcoming-file-stream copy', () {
      expect(
        bookEmptyChaptersMessage(
          const BookItem(
            id: '1',
            sourceId: 'wol',
            sourceName: 'Wol.moe',
            title: '三体',
            format: 'epub',
          ),
        ),
        '该书暂不支持章节阅读。EPUB 文件流会在后续版本接入。',
      );
    });
  });
}
