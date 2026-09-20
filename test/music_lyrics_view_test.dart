import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/widgets/music_lyrics_view.dart';

bool _lineHighlighted(String key) {
  final widget = find.byKey(ValueKey(key)).evaluate().first.widget as Text;
  return widget.style?.fontWeight == FontWeight.w600;
}

void main() {
  testWidgets('shows a static empty state when lyrics are missing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MusicLyricsView(
            lyric: '',
            positionStream: Stream<Duration>.empty(),
          ),
        ),
      ),
    );
    expect(find.text('暂无歌词'), findsOneWidget);
  });

  testWidgets('renders untimed lyrics without a current-line highlight',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MusicLyricsView(
            lyric: '只有文字\n第二行',
            positionStream: Stream<Duration>.empty(),
          ),
        ),
      ),
    );
    expect(find.text('只有文字'), findsOneWidget);
    expect(find.text('第二行'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('只有文字')).style?.fontWeight,
      isNot(FontWeight.w600),
    );
  });

  testWidgets('highlights the timed line for the current position and seek',
      (tester) async {
    final positions = StreamController<Duration>.broadcast();
    addTearDown(positions.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: MusicLyricsView(
              lyric: '[00:00.00]第一句\n[00:10.00]第二句\n[00:20.00]第三句',
              positionStream: positions.stream,
              initialPosition: Duration.zero,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_lineHighlighted('lyric-line-0'), isTrue);
    expect(_lineHighlighted('lyric-line-1'), isFalse);

    positions.add(const Duration(seconds: 10));
    await tester.pump();
    expect(_lineHighlighted('lyric-line-1'), isTrue);
    expect(_lineHighlighted('lyric-line-0'), isFalse);

    positions.add(const Duration(seconds: 3));
    await tester.pump();
    expect(_lineHighlighted('lyric-line-0'), isTrue);
    expect(_lineHighlighted('lyric-line-1'), isFalse);
  });
}
