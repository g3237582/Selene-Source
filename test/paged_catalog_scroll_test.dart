import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/widgets/paged_catalog_scroll.dart';

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

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pump();

    expect(loads, greaterThan(0));
    final offset =
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
    expect(offset, greaterThan(0));

    final loadsBeforeBusy = loads;
    loadingMore.value = true;
    await tester.pump();

    expect(find.text('加载中…'), findsOneWidget);
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      offset,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await tester.pump();
    expect(loads, loadsBeforeBusy);
    expect(find.text('加载中…'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1600));
    await tester.pump();
    expect(find.text('item-0'), findsOneWidget);
    expect(find.text('加载中…'), findsOneWidget);
  });

  testWidgets('does not request another page while a request is already busy',
      (tester) async {
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedCatalogScroll(
            itemCount: 8,
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
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();

    expect(loads, 0);
    expect(find.text('加载中…'), findsOneWidget);
    expect(find.text('row-0'), findsOneWidget);
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
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pump();

    final offset =
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
    expect(offset, greaterThan(0));

    rebuild(() => itemCount = 36);
    await tester.pump();

    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      offset,
    );
    expect(find.text('card-0'), findsNothing);
  });
}
