import '../models/book.dart';
import 'book_catalog.dart';
import 'html_text.dart';

/// LunaTV `GET /api/books/read/chapter` rebuilds 爱下 TXT 缓存 with [tocHref]
/// as the same URL `getChapters()` used. That URL is the legado:chapters
/// acquisition href (tocUrl). Using detailHref here produces different
/// `legado-text:` hashes and returns「全文缓存已失效」.
String resolveBookTocHref(BookItem book) {
  if (!isFileStyleBook(book)) {
    final toc = book.acquisitionHref.trim();
    if (toc.isNotEmpty) {
      return toc;
    }
  }
  if (isBookDetailHref(book.detailHref)) {
    return book.detailHref.trim();
  }
  return resolveBookDetailLocator(book);
}

Map<String, String> bookChapterQuery(BookItem book, BookChapter chapter) {
  final href = chapter.href.trim();
  final tocHref = resolveBookTocHref(book);
  return {
    'sourceId': book.sourceId,
    if (href.isNotEmpty) 'href': href,
    if (tocHref.isNotEmpty) 'tocHref': tocHref,
  };
}

enum ChapterBodyKind { text, empty, challenge, audio, image }

class ChapterBodyView {
  final ChapterBodyKind kind;
  final String displayText;
  final String message;

  const ChapterBodyView({
    required this.kind,
    this.displayText = '',
    this.message = '',
  });
}

final _challengePattern = RegExp(
  r'正在验证浏览器|正在進行安全驗證|請稍等|Just a moment|Attention Required',
  caseSensitive: false,
);

final _audioPattern = RegExp(
  r'<audio\b|audio/mpeg|\.mp3(?:[?#"]|$)',
  caseSensitive: false,
);

final _imagePattern = RegExp(r'<img\b', caseSensitive: false);

bool isBrowserChallengeHtml(String html) {
  return _challengePattern.hasMatch(html);
}

ChapterBodyView inspectChapterBody(String raw) {
  final source = raw.trim();
  if (source.isEmpty) {
    return const ChapterBodyView(
      kind: ChapterBodyKind.empty,
      message: '本章暂无正文',
    );
  }
  if (isBrowserChallengeHtml(source)) {
    return const ChapterBodyView(
      kind: ChapterBodyKind.challenge,
      message: '源站返回了浏览器验证页，暂时无法读取正文。请换一个书源或稍后重试。',
    );
  }
  final text = stripHtml(source);
  if (text.isNotEmpty) {
    return ChapterBodyView(kind: ChapterBodyKind.text, displayText: text);
  }
  if (_audioPattern.hasMatch(source)) {
    return const ChapterBodyView(
      kind: ChapterBodyKind.audio,
      message: '该章是音频内容，当前阅读器不支持播放。请换一个文本书源。',
    );
  }
  if (_imagePattern.hasMatch(source)) {
    return const ChapterBodyView(
      kind: ChapterBodyKind.image,
      message: '该章是图片内容，当前阅读器只显示文本。',
    );
  }
  return const ChapterBodyView(
    kind: ChapterBodyKind.empty,
    message: '本章暂无正文',
  );
}

String bookChapterErrorMessage(Object error, BookItem book) {
  final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  if (raw.contains('全文缓存已失效')) {
    return '全文缓存已失效，请返回详情页重新打开目录后再读正文。';
  }
  if (raw.contains('chapters_not_applicable') ||
      raw.contains('章节目录接口不适用') ||
      raw.contains('文件/OPDS')) {
    return bookFileBookMessage(book);
  }
  if (isFileStyleBook(book) && isLegadoSourceMissingError(error)) {
    return bookFileBookMessage(book);
  }
  final status = _upstreamHttpStatus.firstMatch(raw)?.group(1);
  if (status == '422') {
    return bookFileBookMessage(book);
  }
  if (raw.contains('源站拒绝了正文') || status == '403') {
    final source = book.sourceName.isEmpty ? '该书源' : '「${book.sourceName}」';
    return '源站拒绝了章节正文请求（403）。$source 可能需要登录、Cookie 或更新请求头，请换一个书源或检查后台书源规则。';
  }
  if (status == '404') {
    return '源站没有找到章节正文（404）。请换一个书源试试。';
  }
  if (status != null) {
    return '源站返回 $status，暂时无法拉取正文。请换一个书源或稍后重试。';
  }
  if (raw.contains('缺少 sourceId 或 href') || raw.contains('章节地址缺失')) {
    return '章节地址缺失，无法请求正文。请返回目录重新打开。';
  }
  return raw;
}

final _upstreamHttpStatus = RegExp(r'请求失败\s*[:：]\s*(\d{3})');
