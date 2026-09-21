import 'dart:convert';

import 'package:archive/archive.dart';

List<int> buildFixtureEpub() {
  final archive = Archive()
    ..addFile(_textFile(
      'META-INF/container.xml',
      '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''',
    ))
    ..addFile(_textFile(
      'OEBPS/content.opf',
      '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>朝花夕拾</dc:title>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>''',
    ))
    ..addFile(_textFile(
      'OEBPS/toc.ncx',
      '''<?xml version="1.0"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>狗·猫·鼠</text></navLabel>
      <content src="ch1.xhtml"/>
    </navPoint>
    <navPoint id="np2" playOrder="2">
      <navLabel><text>阿长与山海经</text></navLabel>
      <content src="ch2.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''',
    ))
    ..addFile(_textFile(
      'OEBPS/ch1.xhtml',
      '<html><body><p>从二十多年前，我住在S城的时候……</p></body></html>',
    ))
    ..addFile(_textFile(
      'OEBPS/ch2.xhtml',
      '<html><body><p>长妈妈，已经说过，是一个一向带领着我的女工，说起山海经……</p></body></html>',
    ));
  return ZipEncoder().encode(archive);
}

ArchiveFile _textFile(String name, String text) {
  final bytes = utf8.encode(text);
  return ArchiveFile(name, bytes.length, bytes);
}
