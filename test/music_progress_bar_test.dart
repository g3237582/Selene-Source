import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/widgets/music_progress_bar.dart';

void main() {
  testWidgets('shows an indeterminate track while loading instead of a slider',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MusicProgressBarTrack(
            currentLabel: '00:00',
            durationLabel: '03:21',
            value: 0.4,
            loading: true,
          ),
        ),
      ),
    );

    expect(find.byKey(MusicProgressBarTrack.loadingKey), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('03:21'), findsOneWidget);
  });

  testWidgets('shows a seek slider when playback is ready', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MusicProgressBarTrack(
            currentLabel: '01:02',
            durationLabel: '03:21',
            value: 0.4,
          ),
        ),
      ),
    );

    expect(find.byType(Slider), findsOneWidget);
    expect(find.byKey(MusicProgressBarTrack.loadingKey), findsNothing);
    expect(tester.widget<Slider>(find.byType(Slider)).value, closeTo(0.4, 1e-9));
  });
}
