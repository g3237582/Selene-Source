import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/widgets/paged_catalog_scroll.dart';

ScrollPosition _position(WidgetTester tester) {
  return tester.state<ScrollableState>(find.byType(Scrollable)).position;
}

Future<void> _jumpNearBottom(WidgetTester tester) async {
  final position = _position(tester);
  position.jumpTo(position.maxScrollExtent);
  await tester.pump();
}

void main() {
  testWidgets('keeps catalog items and scroll offset while the next page loads',
      (tester) async {
    final loadingMore = ValueNotifier(false);
    var loads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedCatalogScroll(
            itemCount: 40,
            hasMore: true,
            loadingMoreListenable: loadingMore,
            onLoadMore: () => loads += 1,
            itemBuilder: (context, index) => SizedBox(
              height: 72,
              child: Text('item-$index'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('item-0'), findsOneWidget);
    expect(find.text('加载中…'), findsNothing);
    expect(loads, 0);

    await _jumpNearBottom(tester);
    expect(loads, greaterThan(0));

    final offset = _position(tester).pixels;
    expect(offset, greaterThan(0));

    final loadsBeforeBusy = loads;
    loadingMore.value = true;
    await tester.pump();

    expect(find.text('加载中…'), findsOneWidget);
    expect(_position(tester).pixels, offset);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pump();
    expect(loads, loadsBeforeBusy);
    expect(find.text('加载中…'), findsOneWidget);

    _position(tester).jumpTo(0);
    await tester.pump();
    expect(find.text('item-0'), findsOneWidget);
    expect(loadingMore.value, isTrue);
  });

  testWidgets('does not request another page while a request is already busy',
      (tester) async {
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedCatalogScroll(
            itemCount: 30,
            hasMore: true,
            loadingMore: true,
            onLoadMore: () => loads += 1,
            itemBuilder: (context, index) => SizedBox(
              height: 80,
              child: Text('row-$index'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('row-0'), findsOneWidget);

    await _jumpNearBottom(tester);
    expect(loads, 0);
    expect(find.text('加载中…'), findsOneWidget);
  });

  testWidgets('appends newly loaded items without jumping back to the top',
      (tester) async {
    var itemCount = 20;
    late void Function(void Function()) rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: PagedCatalogScroll(
                itemCount: itemCount,
                hasMore: true,
                loadingMore: false,
                onLoadMore: () {},
                itemBuilder: (context, index) => SizedBox(
                  height: 64,
                  child: Text('card-$index'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await _jumpNearBottom(tester);

    final offset = _position(tester).pixels;
    expect(offset, greaterThan(0));

    rebuild(() => itemCount = 36);
    await tester.pump();

    expect(_position(tester).pixels, offset);
    expect(find.text('card-0'), findsNothing);
  });

  testWidgets(
      'keeps a scroll view and footer when the first search page is still loading',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedCatalogScroll(
            itemCount: 0,
            hasMore: true,
            loadingMore: true,
            onLoadMore: () {},
            empty: const Text('暂无结果'),
            itemBuilder: (context, index) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('加载中…'), findsOneWidget);
    expect(find.text('暂无结果'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
      'does not swap a visible catalog for a spinner when a new search starts',
      (tester) async {
    var itemCount = 18;
    var loadingMore = false;
    late void Function(void Function()) rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: itemCount <= 0 && !loadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : PagedCatalogScroll(
                      itemCount: itemCount,
                      hasMore: true,
                      loadingMore: loadingMore,
                      onLoadMore: () {},
                      itemBuilder: (context, index) => SizedBox(
                        height: 64,
                        child: Text('keep-$index'),
                      ),
                    ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await _jumpNearBottom(tester);
    final offset = _position(tester).pixels;
    expect(offset, greaterThan(0));
    expect(find.text('keep-0'), findsNothing);

    rebuild(() => loadingMore = true);
    await tester.pump();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('keep-0'), findsNothing);
    expect(find.text('加载中…'), findsOneWidget);
    expect(_position(tester).pixels, offset);
  });
}
