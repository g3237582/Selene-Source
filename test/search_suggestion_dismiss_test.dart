import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:selene/services/theme_service.dart';
import 'package:selene/widgets/main_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('touch outside the field and menu dismisses suggestions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _Probe();
    await tester.pumpWidget(_app(harness));
    await _showSuggestion(tester, harness, '繁花推荐');

    await tester.tap(find.text('页面空白'));
    await tester.pump();

    expect(find.byKey(searchSuggestionsKey), findsNothing);
  });

  testWidgets('mouse outside the field and menu dismisses suggestions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _Probe();
    await tester.pumpWidget(_app(harness));
    await _showSuggestion(tester, harness, '繁花推荐');

    await tester.tap(find.text('页面空白'), kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(find.byKey(searchSuggestionsKey), findsNothing);
  });

  testWidgets('tapping a suggestion searches and does not leave the menu open', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _Probe();
    await tester.pumpWidget(_app(harness));
    await _showSuggestion(tester, harness, '繁花推荐');

    await tester.tap(find.text('繁花推荐'), kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(harness.submitted, ['繁花推荐']);
    expect(find.byKey(searchSuggestionsKey), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    await _frames(tester, 4);
    expect(find.byKey(searchSuggestionsKey), findsNothing);
  });

  testWidgets('tapping the input keeps it usable and can show suggestions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _Probe();
    await tester.pumpWidget(_app(harness));
    await _showSuggestion(tester, harness, '繁花推荐');

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.byKey(searchSuggestionsKey), findsOneWidget);

    await tester.tap(find.text('页面空白'));
    await tester.pump();
    expect(find.byKey(searchSuggestionsKey), findsNothing);

    await tester.tap(find.byType(TextField));
    harness.pending.last.complete(const ['再次推荐']);
    await _frames(tester, 4);

    expect(find.text('再次推荐'), findsOneWidget);
    expect(find.byKey(searchSuggestionsKey), findsOneWidget);
  });

  testWidgets('a late suggestion response does not reopen a dismissed menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _Probe();
    await tester.pumpWidget(_app(harness));

    await tester.enterText(find.byType(TextField), '繁');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(harness.pending, hasLength(1));

    await tester.tap(find.text('页面空白'));
    await tester.pump();

    harness.pending.single.complete(const ['迟到推荐']);
    await _frames(tester, 4);

    expect(find.text('迟到推荐'), findsNothing);
    expect(find.byKey(searchSuggestionsKey), findsNothing);
  });

  testWidgets('typing after dismissal shows suggestions again', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _Probe();
    await tester.pumpWidget(_app(harness));
    await _showSuggestion(tester, harness, '繁花推荐');

    await tester.tap(find.text('页面空白'));
    await tester.pump();
    expect(find.byKey(searchSuggestionsKey), findsNothing);

    await tester.enterText(find.byType(TextField), '繁花');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    harness.pending.last.complete(const ['繁花续集']);
    await _frames(tester, 4);

    expect(find.text('繁花续集'), findsOneWidget);
    expect(find.byKey(searchSuggestionsKey), findsOneWidget);
  });

  testWidgets('special-source searches still request special suggestions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _Probe(special: true);
    await tester.pumpWidget(_app(harness));
    await _showSuggestion(tester, harness, '特殊推荐');

    expect(harness.specialFlags, [true]);
  });
}

const searchSuggestionsKey = ValueKey<String>('search-suggestions');

class _Probe {
  _Probe({this.special = false});

  final bool special;
  final List<String> submitted = [];
  final List<Completer<List<String>>> pending = [];
  final List<bool> specialFlags = [];
  String query = '';
}

class _Harness extends StatefulWidget {
  const _Harness(this.probe);

  final _Probe probe;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      content: const SizedBox.expand(child: Text('页面空白')),
      currentBottomNavIndex: 0,
      onBottomNavChanged: (_) {},
      selectedTopTab: 'home',
      onTopTabChanged: (_) {},
      isSearchMode: true,
      showBottomNav: false,
      searchController: controller,
      searchFocusNode: focusNode,
      searchQuery: widget.probe.query,
      specialVideoSource: widget.probe.special,
      suggestionLoader: (text, {required bool special}) {
        widget.probe.specialFlags.add(special);
        final completer = Completer<List<String>>();
        widget.probe.pending.add(completer);
        return completer.future;
      },
      onSearchQueryChanged: (value) => setState(() => widget.probe.query = value),
      onSearchSubmitted: widget.probe.submitted.add,
    );
  }
}

Widget _app(_Probe probe) {
  return ChangeNotifierProvider(
    create: (_) => ThemeService(),
    child: MaterialApp(home: _Harness(probe)),
  );
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    tester.binding.scheduleFrame();
    await tester.pump();
  }
}

Future<void> _showSuggestion(WidgetTester tester, _Probe harness, String text) async {
  await tester.enterText(find.byType(TextField), '繁');
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(harness.pending, isNotEmpty);
  harness.pending.last.complete([text]);
  await _frames(tester, 4);
  expect(find.byKey(searchSuggestionsKey), findsOneWidget);
}
