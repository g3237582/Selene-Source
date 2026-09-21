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

  group('Gutenberg Chinese / OPDS file books', () {
    const gutenbergCatalog = {
      'id': 'urn:gutenberg:25329',
      'bookId': '25329',
      'title': '朝花夕拾',
      'author': 'Lu, Xun',
      'sourceId': 'gutenberg-zh',
      'sourceName': '古腾堡中文',
      'summary': 'Free eBooks since 1971.',
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

    test('catalog payload is a file book, not a Legado chapter locator', () {
      final item = BookItem.fromJson(gutenbergCatalog);

      expect(item.title, '朝花夕拾');
      expect(item.author, 'Lu, Xun');
      expect(item.sourceName, '古腾堡中文');
      expect(item.format, 'epub');
      expect(item.detailHref, 'https://www.gutenberg.org/ebooks/25329.opds');
      expect(shouldFetchBookChapters(item), isFalse);
      expect(
        bookEmptyChaptersMessage(item),
        '该书暂不支持章节阅读。EPUB 文件流会在后续版本接入。',
      );
    });

    test('all-source recommend copies OPDS type so chapters are not requested', () {
      final unlabeled = BookItem.fromJson(const {
        'id': '25329',
        'title': '朝花夕拾',
        'author': 'Lu, Xun',
        'summary': 'Free eBooks since 1971.',
        'detailHref': 'https://www.gutenberg.org/ebooks/25329.opds',
      });
      const source = BookSource(
        id: 'gutenberg-zh',
        name: '古腾堡中文',
        type: 'opds',
        catalogSupported: true,
      );

      expect(unlabeled.sourceType, isEmpty);
      expect(shouldFetchBookChapters(unlabeled), isTrue);

      final labeled = BooksService.attachSource([unlabeled], source).single;
      expect(labeled.sourceId, 'gutenberg-zh');
      expect(labeled.sourceName, '古腾堡中文');
      expect(labeled.sourceType, 'opds');
      expect(shouldFetchBookChapters(labeled), isFalse);
      expect(
        bookEmptyChaptersMessage(labeled),
        '该书暂不支持章节阅读。EPUB 文件流会在后续版本接入。',
      );
    });

    test('Legado source-missing API error is not shown as a chapter failure', () {
      final item = BookItem.fromJson(gutenbergCatalog);
      expect(
        bookChaptersErrorMessage(
          Exception('未找到对应的 Legado 书源'),
          item,
        ),
        '该书暂不支持章节阅读。EPUB 文件流会在后续版本接入。',
      );
    });

    test('detail merge keeps OPDS type and EPUB acquisition format', () {
      const local = BookItem(
        id: '25329',
        sourceId: 'gutenberg-zh',
        sourceName: '古腾堡中文',
        sourceType: 'opds',
        title: '朝花夕拾',
        author: 'Lu, Xun',
        detailHref: 'https://www.gutenberg.org/ebooks/25329.opds',
      );
      final remote = BookItem.fromJson(gutenbergCatalog);

      final merged = mergeBookDetail(remote, local);
      expect(merged.sourceType, 'opds');
      expect(merged.format, 'epub');
      expect(shouldFetchBookChapters(merged), isFalse);
    });

    test('true Legado chapter books still request the chapters API', () {
      const item = BookItem(
        id: 'https://book.example/book/42',
        sourceId: 'legado-a',
        sourceName: '书源A',
        sourceType: 'legado',
        title: '三体',
        detailHref: 'https://book.example/book/42',
      );

      expect(shouldFetchBookChapters(item), isTrue);
      expect(bookChaptersQuery(item)['sourceId'], 'legado-a');
      expect(
        bookChaptersErrorMessage(Exception('未找到对应的 Legado 书源'), item),
        isNot('未找到对应的 Legado 书源'),
      );
    });
  });

  group('猫眼看书 / 活着 title + 403', () {
    const maoyanCard = {
      'id': 'huozhe',
      'name': '活着',
      'author': '余华',
      'sourceId': 'maoyan',
      'sourceName': '猫眼看书',
      'type': 'legado',
      'summary': '地主少爷福贵嗜赌成性，终于赌光了家业一贫如洗。',
      'cover': 'https://cdn.example/huozhe.jpg',
      'detailHref': 'https://www.maoyan.com/book/huozhe',
    };

    test('list cards that only send name keep 活着 instead of 未命名电子书', () {
      final item = BookItem.fromJson(maoyanCard);

      expect(item.title, '活着');
      expect(item.author, '余华');
      expect(item.sourceName, '猫眼看书');
      expect(item.sourceType, 'legado');
      expect(bookDetailRequest(item)['title'], '活着');
      expect(isPlaceholderBookTitle(item.title), isFalse);
    });

    test('placeholder detail title does not overwrite the card title', () {
      final local = BookItem.fromJson(maoyanCard);
      final remote = BookItem.fromJson(const {
        'id': 'huozhe',
        'title': '未命名电子书',
        'author': '余华',
        'sourceId': 'maoyan',
        'sourceName': '猫眼看书',
        'summary': '地主少爷福贵嗜赌成性，终于赌光了家业一贫如洗。',
        'detailHref': 'https://www.maoyan.com/book/huozhe',
      });

      final merged = mergeBookDetail(remote, local);
      expect(merged.title, '活着');
      expect(merged.author, '余华');
      expect(merged.summary, contains('福贵'));
    });

    test('source-site 403 is explained instead of raw 请求失败:403', () {
      final item = BookItem.fromJson(maoyanCard);
      expect(shouldFetchBookChapters(item), isTrue);
      expect(
        bookChaptersErrorMessage(Exception('请求失败:403'), item),
        contains('源站拒绝了章节目录请求'),
      );
      expect(
        bookChaptersErrorMessage(Exception('请求失败:403'), item),
        contains('猫眼看书'),
      );
      expect(
        bookChaptersErrorMessage(Exception('请求失败:403'), item),
        isNot(contains('请求失败:403')),
      );
    });
  });
}
