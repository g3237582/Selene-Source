import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selene/models/music_track.dart';
import 'package:selene/screens/music_player_screen.dart';
import 'package:selene/widgets/music_progress_bar.dart';

const _track = MusicTrack(
  songId: '1',
  source: 'wy',
  name: '测试歌曲',
  artist: '测试歌手',
);

Widget _page({
  required Widget progress,
  bool loading = false,
  String lyric = '[00:00.00]第一句\n[00:10.00]第二句',
  String errorMessage = '',
}) {
  return MaterialApp(
    home: Scaffold(
      body: MusicPlayerPageContent(
        track: _track,
        lyric: lyric,
        positionStream: const Stream<Duration>.empty(),
        progress: progress,
        playing: false,
        loading: loading,
        errorMessage: errorMessage,
        onPrevious: () {},
        onTogglePlay: () {},
        onNext: () {},
      ),
    ),
  );
}

double _top(WidgetTester tester, Key key) {
  return tester.getTopLeft(find.byKey(key)).dy;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('stacks cover, lyrics, progress, then controls from top to bottom',
      (tester) async {
    await tester.pumpWidget(
      _page(
        progress: const SizedBox(height: 32, width: double.infinity),
      ),
    );

    expect(
      _top(tester, MusicPlayerPageKeys.cover),
      lessThan(_top(tester, MusicPlayerPageKeys.title)),
    );
    expect(
      _top(tester, MusicPlayerPageKeys.title),
      lessThan(_top(tester, MusicPlayerPageKeys.artist)),
    );
    expect(
      _top(tester, MusicPlayerPageKeys.artist),
      lessThan(_top(tester, MusicPlayerPageKeys.lyrics)),
    );
    expect(
      _top(tester, MusicPlayerPageKeys.lyrics),
      lessThan(_top(tester, MusicPlayerPageKeys.progress)),
    );
    expect(
      _top(tester, MusicPlayerPageKeys.progress),
      lessThan(_top(tester, MusicPlayerPageKeys.controls)),
    );
  });

  testWidgets('does not show a standalone loading bar outside the progress slot',
      (tester) async {
    await tester.pumpWidget(
      _page(
        loading: true,
        progress: const MusicProgressBarTrack(
          currentLabel: '00:00',
          durationLabel: '00:00',
          value: 0,
          loading: true,
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(MusicPlayerPageKeys.progress),
        matching: find.byKey(MusicProgressBarTrack.loadingKey),
      ),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);
  });
}
