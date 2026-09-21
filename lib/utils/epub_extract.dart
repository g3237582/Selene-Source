import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/book.dart';
import 'html_text.dart';

class EpubExtractedChapter {
  final BookChapter chapter;
  final String content;

  const EpubExtractedChapter({
    required this.chapter,
    required this.content,
  });
}

List<EpubExtractedChapter> extractEpubChapters(List<int> bytes) {
  if (bytes.length < 4 ||
      bytes[0] != 0x50 ||
      bytes[1] != 0x4b ||
      bytes[2] != 0x03 ||
      bytes[3] != 0x04) {
    throw const FormatException('不是有效的 EPUB/ZIP 文件');
  }
  final archive = ZipDecoder().decodeBytes(bytes);
  final files = <String, ArchiveFile>{};
  for (final file in archive.files) {
    if (!file.isFile) {
      continue;
    }
    files[_normalizeZipPath(file.name)] = file;
  }
  final rootPath = _readRootfilePath(files);
  final opfBytes = _requireFile(files, rootPath);
  final opf = XmlDocument.parse(utf8.decode(opfBytes));
  final opfDir = _parentPath(rootPath);
  final manifest = _readManifest(opf, opfDir);
  final titles = {
    ..._readNcxTitles(files, opf, opfDir, manifest),
    ..._readNavTitles(files, opf, opfDir, manifest),
  };
  final extracted = <EpubExtractedChapter>[];
  var order = 0;
  for (final href in _readSpineHrefs(opf, manifest)) {
    final file = files[_normalizeZipPath(href)];
    if (file == null) {
      continue;
    }
    final content = stripHtml(utf8.decode(file.content as List<int>));
    if (content.isEmpty) {
      continue;
    }
    final title = firstNonEmptyString([
      titles[_normalizeZipPath(href)],
      titles[_basename(href)],
    ], fallback: '第${order + 1}章');
    extracted.add(
      EpubExtractedChapter(
        chapter: BookChapter(
          id: href,
          title: title,
          href: href,
          order: order,
        ),
        content: content,
      ),
    );
    order += 1;
  }
  if (extracted.isEmpty) {
    throw const FormatException('EPUB 中没有可阅读的章节');
  }
  return extracted;
}

Map<String, String> epubChapterContents(List<EpubExtractedChapter> chapters) {
  return {
    for (final item in chapters) item.chapter.href: item.content,
  };
}

String _readRootfilePath(Map<String, ArchiveFile> files) {
  final container = _requireFile(files, 'META-INF/container.xml');
  final document = XmlDocument.parse(utf8.decode(container));
  final rootfile = document
      .findAllElements('rootfile')
      .map((node) => node.getAttribute('full-path') ?? '')
      .firstWhere((path) => path.trim().isNotEmpty, orElse: () => '');
  if (rootfile.isEmpty) {
    throw const FormatException('EPUB 缺少 OPF 路径');
  }
  return _normalizeZipPath(rootfile);
}

Map<String, String> _readManifest(XmlDocument opf, String opfDir) {
  final items = <String, String>{};
  for (final item in opf.findAllElements('item')) {
    final id = item.getAttribute('id') ?? '';
    final href = item.getAttribute('href') ?? '';
    if (id.isEmpty || href.isEmpty) {
      continue;
    }
    items[id] = _resolveZipPath(opfDir, href);
  }
  return items;
}

Iterable<String> _readSpineHrefs(
  XmlDocument opf,
  Map<String, String> manifest,
) sync* {
  for (final itemref in opf.findAllElements('itemref')) {
    final idref = itemref.getAttribute('idref') ?? '';
    final href = manifest[idref];
    if (href == null || href.isEmpty) {
      continue;
    }
    final lower = href.toLowerCase();
    if (lower.endsWith('.ncx') ||
        lower.endsWith('.css') ||
        lower.endsWith('.js')) {
      continue;
    }
    yield href;
  }
}

Map<String, String> _readNcxTitles(
  Map<String, ArchiveFile> files,
  XmlDocument opf,
  String opfDir,
  Map<String, String> manifest,
) {
  final tocId = opf
      .findAllElements('spine')
      .map((node) => node.getAttribute('toc') ?? '')
      .firstWhere((id) => id.isNotEmpty, orElse: () => '');
  final ncxPath = firstNonEmptyString([
    if (tocId.isNotEmpty) manifest[tocId],
    ...manifest.values.where((href) => href.toLowerCase().endsWith('.ncx')),
  ]);
  if (ncxPath.isEmpty || files[_normalizeZipPath(ncxPath)] == null) {
    return const {};
  }
  final document = XmlDocument.parse(
    utf8.decode(files[_normalizeZipPath(ncxPath)]!.content as List<int>),
  );
  final titles = <String, String>{};
  for (final point in document.findAllElements('navPoint')) {
    final label = point
        .findElements('navLabel')
        .expand((node) => node.findElements('text'))
        .map((node) => node.innerText.trim())
        .firstWhere((text) => text.isNotEmpty, orElse: () => '');
    final src = point
        .findElements('content')
        .map((node) => node.getAttribute('src') ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (label.isEmpty || src.isEmpty) {
      continue;
    }
    final href = _resolveZipPath(_parentPath(ncxPath), _stripFragment(src));
    titles[_normalizeZipPath(href)] = label;
    titles[_basename(href)] = label;
  }
  return titles;
}

Map<String, String> _readNavTitles(
  Map<String, ArchiveFile> files,
  XmlDocument opf,
  String opfDir,
  Map<String, String> manifest,
) {
  final navHref = manifest.values.firstWhere(
    (href) => href.toLowerCase().endsWith('nav.xhtml'),
    orElse: () => '',
  );
  if (navHref.isEmpty || files[_normalizeZipPath(navHref)] == null) {
    return const {};
  }
  final document = XmlDocument.parse(
    utf8.decode(files[_normalizeZipPath(navHref)]!.content as List<int>),
  );
  final titles = <String, String>{};
  for (final anchor in document.findAllElements('a')) {
    final href = _stripFragment(anchor.getAttribute('href') ?? '');
    final label = anchor.innerText.trim();
    if (href.isEmpty || label.isEmpty) {
      continue;
    }
    final resolved = _resolveZipPath(_parentPath(navHref), href);
    titles[_normalizeZipPath(resolved)] = label;
    titles[_basename(resolved)] = label;
  }
  return titles;
}

List<int> _requireFile(Map<String, ArchiveFile> files, String path) {
  final file = files[_normalizeZipPath(path)];
  if (file == null) {
    throw FormatException('EPUB 缺少 $path');
  }
  return file.content as List<int>;
}

String _normalizeZipPath(String path) {
  return path.replaceAll('\\', '/').replaceFirst(RegExp(r'^(\./)+'), '');
}

String _parentPath(String path) {
  final normalized = _normalizeZipPath(path);
  final index = normalized.lastIndexOf('/');
  return index < 0 ? '' : normalized.substring(0, index);
}

String _basename(String path) {
  final normalized = _normalizeZipPath(_stripFragment(path));
  final index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.substring(index + 1);
}

String _stripFragment(String path) {
  final index = path.indexOf('#');
  return index < 0 ? path : path.substring(0, index);
}

String _resolveZipPath(String directory, String href) {
  final relative = _normalizeZipPath(_stripFragment(href));
  if (relative.startsWith('/')) {
    return relative.substring(1);
  }
  if (directory.isEmpty) {
    return relative;
  }
  final parts = <String>[
    ...directory.split('/').where((part) => part.isNotEmpty),
    ...relative.split('/').where((part) => part.isNotEmpty),
  ];
  final resolved = <String>[];
  for (final part in parts) {
    if (part == '.') {
      continue;
    }
    if (part == '..') {
      if (resolved.isNotEmpty) {
        resolved.removeLast();
      }
      continue;
    }
    resolved.add(part);
  }
  return resolved.join('/');
}
