import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/book.dart';
import 'package:selene/models/book_file.dart';
import 'package:selene/utils/book_catalog.dart';
import 'package:selene/utils/epub_extract.dart';

import 'epub_fixture.dart';

void main() {
  const lunaTv422 = {
    'error':
        '当前书源为文件/OPDS 资源，章节目录接口不适用。请使用 /api/books/file 或 /api/books/read/manifest 获取整本文件。',
    'code': 'chapters_not_applicable',
    'sourceType': 'opds',
    'format': 'epub',
    'acquisitionHint': '/api/books/file',
    'manifestHint': '/api/books/read/manifest',
  };

  group('422 chapters_not_applicable payload', () {
    test('parses LunaTV OPDS/EPUB rejection with file and manifest hints', () {
      final payload = BookChaptersNotApplicable.tryParse(
        lunaTv422,
        statusCode: 422,
      );

      expect(payload, isNotNull);
      expect(payload!.code, BookChaptersNotApplicable.notApplicableCode);
      expect(payload.sourceType, 'opds');
      expect(payload.format, 'epub');
      expect(payload.acquisitionHint, '/api/books/file');
      expect(payload.manifestHint, '/api/books/read/manifest');
      expect(payload.error, contains('/api/books/file'));
      expect(payload.isEpub, isTrue);
    });

    test('accepts snake_case hint keys and equivalent code', () {
      final payload = BookChaptersNotApplicable.tryParse({
        'code': 'CHAPTERS_NOT_APPLICABLE',
        'source_type': 'opds',
        'format': 'pdf',
        'acquisition_hint': '/api/books/file',
        'manifest_hint': '/api/books/read/manifest',
        'error': 'chapters not applicable',
      });

      expect(payload, isNotNull);
      expect(payload!.format, 'pdf');
      expect(payload.acquisitionHint, '/api/books/file');
      expect(payload.manifestHint, '/api/books/read/manifest');
      expect(payload.isEpub, isFalse);
    });

    test('treats 422 plus hints as applicable even without a code', () {
      final payload = BookChaptersNotApplicable.tryParse({
        'error': 'use the file API',
        'acquisitionHint': '/api/books/file',
        'manifestHint': '/api/books/read/manifest',
        'format': 'epub',
      }, statusCode: 422);

      expect(payload, isNotNull);
      expect(payload!.code, BookChaptersNotApplicable.notApplicableCode);
    });

    test('does not treat a real Legado 403 body as a file-book hint', () {
      expect(
        BookChaptersNotApplicable.tryParse({
          'error': '请求失败:403',
        }, statusCode: 403),
        isNull,
      );
      expect(
        BookChaptersNotApplicable.tryParse({
          'error': '源站拒绝了目录抓取（可能需登录/Cookie/更新请求头）',
        }, statusCode: 500),
        isNull,
      );
    });
  });

  group('acquisition / manifest open plan', () {
    const book = BookItem(
      id: 'https://www.gutenberg.org/ebooks/25329.opds',
      sourceId: 'gutenberg-zh',
      sourceName: '古腾堡中文',
      sourceType: 'opds',
      title: '朝花夕拾',
      author: 'Lu, Xun',
      detailHref: 'https://www.gutenberg.org/ebooks/25329.opds',
      format: 'epub',
      acquisitionHref: 'https://www.gutenberg.org/ebooks/25329.epub.images',
    );

    test('builds authenticated file and manifest requests from 422 hints', () {
      final hints = BookChaptersNotApplicable.tryParse(
        lunaTv422,
        statusCode: 422,
      )!;
      final plan = BookFileOpenPlan.from(
        book: book,
        hints: hints,
      );

      expect(plan.fileEndpoint, '/api/books/file');
      expect(plan.manifestEndpoint, '/api/books/read/manifest');
      expect(plan.preferInAppReader, isTrue);
      expect(plan.fileBody['sourceId'], 'gutenberg-zh');
      expect(plan.fileBody['bookId'], book.id);
      expect(plan.fileBody['href'], book.acquisitionHref);
      expect(plan.fileBody['format'], 'epub');
      expect(plan.manifestBody['sourceId'], 'gutenberg-zh');
      expect(plan.manifestBody['href'], book.detailHref);
      expect(plan.manifestBody['title'], '朝花夕拾');
    });

    test('prefers manifest fileUrl and acquisitionHref when present', () {
      final hints = BookChaptersNotApplicable.tryParse(lunaTv422)!;
      final manifest = BookReadManifest.fromJson({
        'book': {
          'id': '25329',
          'title': '朝花夕拾',
          'sourceId': 'gutenberg-zh',
          'sourceName': '古腾堡中文',
          'detailHref': 'https://www.gutenberg.org/ebooks/25329.opds',
          'acquisitionLinks': [
            {
              'type': 'application/epub+zip',
              'href': 'https://www.gutenberg.org/ebooks/25329.epub.images',
            },
          ],
        },
        'format': 'epub',
        'fileUrl':
            '/api/books/file?sourceId=gutenberg-zh&bookId=25329&format=epub',
        'acquisitionHref':
            'https://www.gutenberg.org/ebooks/25329.epub.images',
        'cacheKey': 'gutenberg-zh::25329::epub',
      });

      expect(manifest.fileUrl, contains('/api/books/file?'));
      expect(manifest.acquisitionHref, contains('.epub.images'));
      expect(manifest.format, 'epub');
      expect(manifest.book.title, '朝花夕拾');

      final plan = BookFileOpenPlan.from(
        book: book,
        hints: hints,
        manifest: manifest,
      );
      expect(plan.fileUrl, manifest.fileUrl);
      expect(plan.fileBody['href'], manifest.acquisitionHref);
    });
  });

  group('422 vs 403 operator copy', () {
    const opds = BookItem(
      id: '25329',
      sourceId: 'gutenberg-zh',
      sourceName: '古腾堡中文',
      sourceType: 'opds',
      title: '朝花夕拾',
      format: 'epub',
    );
    const legado = BookItem(
      id: 'huozhe',
      sourceId: 'maoyan',
      sourceName: '猫眼看书',
      sourceType: 'legado',
      title: '活着',
    );

    test('OPDS books still probe chapters so LunaTV 422 can be consumed', () {
      expect(isFileStyleBook(opds), isTrue);
      expect(shouldFetchBookChapters(opds), isTrue);
      expect(shouldFetchBookChapters(legado), isTrue);
    });

    test('422 file-book signal is not shown as a source-site 403', () {
      final hints = BookChaptersNotApplicable.tryParse(
        lunaTv422,
        statusCode: 422,
      )!;
      final message = bookChaptersErrorMessage(
        BookChaptersNotApplicableException(hints),
        opds,
      );
      expect(message, contains('整本'));
      expect(message, isNot(contains('源站拒绝了章节目录请求')));
      expect(message, isNot(contains('请求失败:403')));
      expect(
        bookChaptersErrorMessage(Exception('请求失败:422'), opds),
        contains('整本'),
      );
    });

    test('true Legado 403 still explains the source-site rejection', () {
      expect(
        bookChaptersErrorMessage(Exception('请求失败:403'), legado),
        contains('源站拒绝了章节目录请求'),
      );
      expect(
        BookChaptersNotApplicable.tryParse(
          const {'error': '请求失败:403'},
          statusCode: 403,
        ),
        isNull,
      );
    });

    test('placeholder titles stay ignored when merging file-book detail', () {
      const local = BookItem(
        id: 'huozhe',
        sourceId: 'maoyan',
        sourceName: '猫眼看书',
        title: '活着',
      );
      final remote = BookItem.fromJson(const {
        'id': 'huozhe',
        'title': '未命名电子书',
        'author': '余华',
        'sourceId': 'maoyan',
      });
      expect(mergeBookDetail(remote, local).title, '活着');
    });
  });

  group('EPUB extract', () {
    test('reads spine chapters and NCX titles from a zip EPUB', () {
      final chapters = extractEpubChapters(buildFixtureEpub());
      expect(chapters.map((item) => item.chapter.title), [
        '狗·猫·鼠',
        '阿长与山海经',
      ]);
      expect(chapters.first.content, contains('从二十多年前'));
      expect(chapters.last.content, contains('山海经'));
    });
  });
}
