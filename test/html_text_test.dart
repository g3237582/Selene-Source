import 'package:flutter_test/flutter_test.dart';
import 'package:selene/utils/html_text.dart';

void main() {
  test('turns common chapter markup into readable text', () {
    expect(
      stripHtml('<p>第一段</p><br/><p>第二段&nbsp;继续</p>'),
      '第一段\n\n第二段 继续',
    );
  });

  test('drops tags without losing chinese copy', () {
    expect(stripHtml('<div class="content">你好世界</div>'), '你好世界');
  });
}
