import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<String> saveBookBytes({
  required List<int> bytes,
  required String title,
  required String format,
}) async {
  if (kIsWeb) {
    throw Exception('当前平台无法保存电子书文件');
  }
  final directory = await getTemporaryDirectory();
  final safeTitle = title.replaceAll(RegExp(r'[/:*?"<>|]'), '_').trim();
  final extension = format.toLowerCase() == 'pdf' ? 'pdf' : 'epub';
  final name = (safeTitle.isEmpty ? 'ebook' : safeTitle).replaceAll(
    RegExp(r'\s+'),
    '_',
  );
  final file = File('${directory.path}/$name.$extension');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<void> openBookBytesWithSystem({
  required List<int> bytes,
  required String title,
  required String format,
  String? remoteUrl,
}) async {
  if (kIsWeb) {
    final href = remoteUrl?.trim() ?? '';
    if (href.isEmpty) {
      throw Exception('当前平台无法打开电子书文件');
    }
    final uri = Uri.parse(href);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('无法打开电子书');
    }
    return;
  }
  final path = await saveBookBytes(
    bytes: bytes,
    title: title,
    format: format,
  );
  final uri = Uri.file(path);
  if (await canLaunchUrl(uri)) {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (launched) {
      return;
    }
  }
  throw Exception('已保存到 $path，请用系统阅读器打开');
}
