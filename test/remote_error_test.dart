import 'package:flutter_test/flutter_test.dart';
import 'package:selene/utils/remote_error.dart';

void main() {
  const ageGateDump =
      'exception while fetching data (/fetchedChapters): '
      '偶然与哥哥的朋友一起看漫画被列为限制漫画，其中部分章节可能会有暴力、血腥、色情或不适当的语言等内容，'
      '不适合未成年观众，为保护未成年人，我将对偶然与哥哥的朋友一起看漫画进行屏蔽。'
      '如果你法定年龄已超过18岁，点此处继续阅读！\n'
      'java.lang.Exception: 偶然与哥哥的朋友一起看漫画被列为限制漫画\n'
      'at eu.kanade.tachiyomi.source.online.HttpSource.fetchChapterList\n'
      'at suwayomi.tachidesk.manga.impl.util.lang.RxCoroutineBridge.awaitOne';

  test('age-gated chapter fetch becomes a short readable message', () {
    expect(
      sanitizeRemoteError(ageGateDump, fallback: '获取漫画详情失败'),
      '该漫画被源站列为限制内容。确认已满18岁后，可回传确认指令继续获取目录。',
    );
  });

  test('age-gated chapter fetch exposes a confirm-adult command', () {
    final parsed = parseRemoteError(ageGateDump, fallback: '获取漫画详情失败');
    expect(parsed.command, kConfirmAdultCommand);
    expect(parsed.commandLabel, kConfirmAdultLabel);
  });

  test('API action overrides inferred command', () {
    final parsed = parseRemoteError(
      '源站暂时无法访问',
      fallback: '获取漫画详情失败',
      action: const {
        'type': 'confirmAdult',
        'command': kConfirmAdultCommand,
        'label': '继续阅读',
      },
    );
    expect(parsed.command, kConfirmAdultCommand);
    expect(parsed.commandLabel, '继续阅读');
    expect(parsed.message, '源站暂时无法访问');
  });

  test('java stack traces are stripped from ordinary fetch errors', () {
    const dump =
        'Exception: exception while fetching data (/fetchedChapters): 源站暂时无法访问\n'
        'java.lang.IllegalStateException: 源站暂时无法访问\n'
        'at eu.kanade.tachiyomi.source.online.HttpSource.fetchChapterList';
    expect(sanitizeRemoteError(dump, fallback: '获取漫画详情失败'), '源站暂时无法访问');
  });

  test('empty or stack-only errors use the fallback', () {
    expect(
      sanitizeRemoteError(
        'at eu.kanade.tachiyomi.source.online.HttpSource.fetchChapterList',
        fallback: '获取漫画详情失败',
      ),
      '获取漫画详情失败',
    );
  });
}
