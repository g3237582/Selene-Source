const kConfirmAdultCommand = 'manga.confirmAdult';
const kConfirmAdultLabel = '点击此处继续阅读';

class RemoteErrorInfo {
  final String message;
  final String? command;
  final String? commandLabel;

  const RemoteErrorInfo({
    required this.message,
    this.command,
    this.commandLabel,
  });

  bool get hasCommand => command != null && command!.isNotEmpty;
}

class MangaRemoteException implements Exception {
  final RemoteErrorInfo info;

  const MangaRemoteException(this.info);

  @override
  String toString() => info.message;
}

RemoteErrorInfo parseRemoteError(
  Object error, {
  String fallback = '操作失败',
  Map<String, dynamic>? action,
}) {
  if (error is MangaRemoteException) {
    return error.info;
  }
  final message = sanitizeRemoteError(error, fallback: fallback);
  final fromAction = _commandFromAction(action);
  if (fromAction != null) {
    return RemoteErrorInfo(
      message: message,
      command: fromAction.$1,
      commandLabel: fromAction.$2,
    );
  }
  if (_ageGate.hasMatch(message) || _ageGate.hasMatch(error.toString())) {
    return const RemoteErrorInfo(
      message: '该漫画被源站列为限制内容。确认已满18岁后，可回传确认指令继续获取目录。',
      command: kConfirmAdultCommand,
      commandLabel: kConfirmAdultLabel,
    );
  }
  return RemoteErrorInfo(message: message);
}

String sanitizeRemoteError(Object error, {String fallback = '操作失败'}) {
  var text = error.toString().trim();
  if (text.isEmpty) {
    return fallback;
  }

  text = text.replaceFirst(RegExp(r'^Exception:\s*'), '');
  if (error is MangaRemoteException) {
    return error.info.message.isEmpty ? fallback : error.info.message;
  }
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) => !_stackLine.hasMatch(line))
      .map(_stripPrefixes)
      .where((line) => line.isNotEmpty)
      .toList();

  final unique = <String>[];
  for (final line in lines) {
    if (!unique.contains(line)) {
      unique.add(line);
    }
  }
  final cleaned = unique.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) {
    return fallback;
  }
  if (_ageGate.hasMatch(cleaned)) {
    return '该漫画被源站列为限制内容。确认已满18岁后，可回传确认指令继续获取目录。';
  }
  return cleaned;
}

(String, String)? _commandFromAction(Map<String, dynamic>? action) {
  if (action == null) {
    return null;
  }
  final command = action['command']?.toString().trim() ?? '';
  if (command.isEmpty) {
    return null;
  }
  final label = action['label']?.toString().trim();
  return (
    command,
    (label == null || label.isEmpty) ? kConfirmAdultLabel : label,
  );
}

final _stackLine = RegExp(
  r'^(at\s+\S+|Caused by:|Suppressed:)',
  caseSensitive: false,
);

final _ageGate = RegExp(
  r'限制漫画|继续阅读|法定年龄|未成年|18\s*岁',
);

String _stripPrefixes(String line) {
  return line
      .replaceFirst(RegExp(r'^exception while fetching data \([^)]+\):\s*'), '')
      .replaceFirst(RegExp(r'^[a-zA-Z.]*(Exception|Error):\s*'), '')
      .trim();
}
