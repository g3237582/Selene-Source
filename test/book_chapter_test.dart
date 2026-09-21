import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/book.dart';
import 'package:selene/utils/book_chapter.dart';

void main() {
  group('LunaTV /api/books/read/chapter query', () {
    const aixia = BookItem(
      id: 'https://ixdzs8.com/read/117097/',
      sourceId: 'legado_d43d71625efe0dab',
      sourceName: '爱下电子书',
      sourceType: 'legado',
      title: '活着',
      author: '余华',
      detailHref: 'https://ixdzs8.com/read/117097/',
      format: 'chapters',
      acquisitionHref: 'https://ixdzs8.com/read/117097/toc/',
    );
    const textChapter = BookChapter(
      id: 'ch-0',
      title: '前言',
      href: 'legado-text:a1b2c3d4e5f60789',
      order: 0,
    );

    test('requires sourceId + TOC href, and also sends bookId/bookUrl', () {
      final query = bookChapterQuery(aixia, textChapter);

      expect(isValidChapterBodyQuery(query), isTrue);
      expect(query['sourceId'], 'legado_d43d71625efe0dab');
      expect(query['href'], 'legado-text:a1b2c3d4e5f60789');
      expect(query['href'], isNot(textChapter.id));
      expect(query['bookId'], 'https://ixdzs8.com/read/117097/');
      expect(query['bookUrl'], 'https://ixdzs8.com/read/117097/');
      expect(query['tocHref'], 'https://ixdzs8.com/read/117097/toc/');
      expect(query['tocHref'], isNot(aixia.detailHref));
    });

    test('chapterId-only payload is not a valid body request', () {
      final chapter = BookChapter.fromJson(const {
        'id': 'ch-99',
        'title': '前言',
      });
      final query = bookChapterQuery(aixia, chapter);

      expect(chapter.href, isEmpty);
      expect(query.containsKey('href'), isFalse);
      expect(query['href'], isNot('ch-99'));
      expect(isValidChapterBodyQuery(query), isFalse);
    });

    test('falls back to bookUrl/detailHref when detail has no TOC link', () {
      final query = bookChapterQuery(
        aixia.copyWith(acquisitionHref: ''),
        textChapter,
      );

      expect(query['href'], 'legado-text:a1b2c3d4e5f60789');
      expect(query['tocHref'], 'https://ixdzs8.com/read/117097/');
    });

    test('does not send an EPUB file URL as tocHref', () {
      const gutenberg = BookItem(
        id: 'https://www.gutenberg.org/ebooks/25329.opds',
        sourceId: 'gutenberg-zh',
        sourceName: '古腾堡中文',
        sourceType: 'opds',
        title: '朝花夕拾',
        detailHref: 'https://www.gutenberg.org/ebooks/25329.opds',
        format: 'epub',
        acquisitionHref: 'https://www.gutenberg.org/ebooks/25329.epub.images',
      );
      const chapter = BookChapter(
        id: 'spine-1',
        title: '小引',
        href: 'OEBPS/ch1.xhtml',
      );

      final query = bookChapterQuery(gutenberg, chapter);
      expect(query['href'], 'OEBPS/ch1.xhtml');
      expect(query['tocHref'], 'https://www.gutenberg.org/ebooks/25329.opds');
      expect(query['tocHref'], isNot(contains('.epub')));
    });

    test('keeps http chapter URLs used by ordinary Legado ruleContent sources', () {
      const chapter = BookChapter(
        id: '42-3',
        title: '第三章',
        href: 'https://book.example/book/42/3.html',
        order: 3,
      );
      final query = bookChapterQuery(
        const BookItem(
          id: 'https://book.example/book/42',
          sourceId: 'legado-a',
          sourceName: '书源A',
          sourceType: 'legado',
          title: '三体',
          detailHref: 'https://book.example/book/42',
          acquisitionHref: 'https://book.example/book/42/toc',
        ),
        chapter,
      );

      expect(query['href'], 'https://book.example/book/42/3.html');
      expect(query['tocHref'], 'https://book.example/book/42/toc');
    });
  });

  group('chapter list / body field aliases', () {
    test('chapter href falls back to url / chapterUrl / index', () {
      final chapter = BookChapter.fromJson(const {
        'id': '',
        'title': '第一章',
        'url': 'https://book.example/c/1',
        'index': 1,
      });

      expect(chapter.href, 'https://book.example/c/1');
      expect(chapter.order, 1);
      expect(chapter.id, isNotEmpty);

      final fromChapterUrl = BookChapter.fromJson(const {
        'title': '第二章',
        'chapterUrl': '/read/2.html',
        'order': 2,
      });
      expect(fromChapterUrl.href, '/read/2.html');
      expect(fromChapterUrl.order, 2);
    });

    test('body reads content, then text/body/html, then nested chapter', () {
      expect(
        BookChapterContent.fromJson(const {
          'id': 'c1',
          'title': '前言',
          'href': 'legado-text:aaa',
          'content': '一位真正的作家永远只为内心写作。',
        }).content,
        contains('一位真正的作家'),
      );
      expect(
        BookChapterContent.fromJson(const {
          'title': '前言',
          'text': '家珍还是一个女学生。',
        }).content,
        '家珍还是一个女学生。',
      );
      expect(
        BookChapterContent.fromJson(const {
          'data': {
            'chapter': {
              'body': '福贵说到这里看着我嘿嘿笑了。',
            },
          },
        }).content,
        '福贵说到这里看着我嘿嘿笑了。',
      );
    });
  });

  group('chapter body classification', () {
    test('plain 爱下 text is readable after HTML strip', () {
      final view = inspectChapterBody('一位真正的作家永远只为内心写作。');
      expect(view.kind, ChapterBodyKind.text);
      expect(view.displayText, contains('一位真正的作家'));
    });

    test('browser-challenge HTML is not shown as the chapter', () {
      final view = inspectChapterBody(
        '<html><head><title>正在验证浏览器</title></head>'
        '<body>請稍等，正在進行安全驗證...</body></html>',
      );
      expect(view.kind, ChapterBodyKind.challenge);
      expect(view.message, contains('验证'));
      expect(view.displayText, isEmpty);
    });

    test('audio-only markup is not treated as empty text', () {
      final view = inspectChapterBody(
        '<audio src="https://cdn.example/ch1.mp3"></audio>',
      );
      expect(view.kind, ChapterBodyKind.audio);
      expect(view.message, contains('音频'));
    });

    test('image-only HTML is not collapsed to 本章暂无正文', () {
      final view = inspectChapterBody(
        '<div class="content"><img src="/api/books/image?url=1.jpg"></div>',
      );
      expect(view.kind, ChapterBodyKind.image);
      expect(view.message, contains('图片'));
    });

    test('true empty body keeps a dedicated empty state', () {
      final view = inspectChapterBody('   ');
      expect(view.kind, ChapterBodyKind.empty);
      expect(view.message, '本章暂无正文');
    });

    test('内容还在处理中 is shown as body text, not a blank error', () {
      final view = inspectChapterBody('内容还在处理中');
      expect(view.kind, ChapterBodyKind.text);
      expect(view.displayText, '内容还在处理中');
      expect(view.message, isEmpty);
    });
  });

  group('chapter title fallback', () {
    const toc = BookChapter(
      id: 'ch-0',
      title: '前言',
      href: 'legado-text:a1b2c3d4e5f60789',
    );

    test('empty API title uses the TOC entry title', () {
      expect(resolveChapterTitle(tocChapter: toc, apiTitle: ''), '前言');
      expect(resolveChapterTitle(tocChapter: toc), '前言');
    });

    test('placeholder API title does not replace the TOC title', () {
      expect(
        resolveChapterTitle(tocChapter: toc, apiTitle: '未命名'),
        '前言',
      );
    });

    test('real API title wins over the TOC title', () {
      expect(
        resolveChapterTitle(tocChapter: toc, apiTitle: '序章'),
        '序章',
      );
    });
  });

  group('chapter body errors', () {
    const aixia = BookItem(
      id: 'https://ixdzs8.com/read/117097/',
      sourceId: 'legado_d43d71625efe0dab',
      sourceName: '爱下电子书',
      sourceType: 'legado',
      title: '活着',
      detailHref: 'https://ixdzs8.com/read/117097/',
    );

    test('maps TXT cache miss to a reopen-catalog message', () {
      expect(
        bookChapterErrorMessage(Exception('全文缓存已失效，请重新打开目录'), aixia),
        contains('重新打开目录'),
      );
    });

    test('maps source-site 403 to a body-specific explanation', () {
      expect(
        bookChapterErrorMessage(Exception('源站拒绝了正文抓取（可能需登录/Cookie/更新请求头）'), aixia),
        contains('正文'),
      );
      expect(
        bookChapterErrorMessage(Exception('请求失败:403'), aixia),
        contains('爱下电子书'),
      );
      expect(
        bookChapterErrorMessage(Exception('源站拒绝了正文抓取（可能需登录/Cookie/更新请求头）'), aixia),
        contains('客户端无法绕过'),
      );
    });

    test('猫眼看书 refusal copy does not imply Selene can scrape past 403', () {
      const maoyan = BookItem(
        id: 'https://www.maoyan.com/book/huozhe',
        sourceId: 'maoyan',
        sourceName: '猫眼看书',
        sourceType: 'legado',
        title: '活着',
        detailHref: 'https://www.maoyan.com/book/huozhe',
      );
      final message = bookChapterErrorMessage(
        Exception('源站拒绝了正文抓取（可能需登录/Cookie/更新请求头）'),
        maoyan,
      );
      expect(message, contains('猫眼看书'));
      expect(message, contains('源站拒绝'));
      expect(message, contains('客户端无法绕过'));
      expect(message, contains('换一个可用书源'));
    });

    test('maps OPDS 422 to the file-book path instead of a chapter failure', () {
      expect(
        bookChapterErrorMessage(
          Exception('当前书源为文件/OPDS 资源，章节目录接口不适用。'),
          const BookItem(
            id: '25329',
            sourceId: 'gutenberg-zh',
            sourceName: '古腾堡中文',
            sourceType: 'opds',
            title: '朝花夕拾',
            format: 'epub',
          ),
        ),
        contains('整本'),
      );
    });
  });
}
