# Selene Dynamic Island Implementation Plan

> **已废止（superseded）。** 应用内顶部 Dynamic Island 不再是产品方案。  
> 意图 UX 是系统 MediaSession：`MusicMediaSession` + `MusicAudioHandler` + `audio_service` 通知栏 / 锁屏控件，以及底部 `MusicMiniPlayer`。  
> 本计划仅作 PR #9 的历史实现记录，不要再按下文挂载 `MusicDynamicIsland`。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ~~Add a top floating music Dynamic Island (收起环进度胶囊 / 展开播放控件) that coexists with the bottom mini player and lock-screen media card.~~ **Superseded:** do not ship an in-app island.

**Architecture:** Pure in-app overlay widget driven by `MusicPlayerService` + `player.stream.position`. Mount inside `MainLayout`'s existing `Stack` as a top `Positioned` layer. Hide when the current route is `MusicPlayerScreen`. Do not change audio_service lock-screen behavior.

**Tech Stack:** Flutter / Dart, existing `MusicPlayerService` (media_kit `Player`), `AuthenticatedImage`, `MainLayout` shell.

**Spec:** `docs/superpowers/specs/2026-09-20-selene-dynamic-island-design.md`

## Global Constraints

- Keep bottom `MusicMiniPlayer` and lock-screen / notification media card unchanged in responsibility.
- Show island only when `MusicPlayerService.instance.current != null` and current route is not `MusicPlayerScreen`.
- Collapsed: top-center dark capsule + outer thin progress ring.
- Expanded: widen to prev / play-pause / next; collapse on outside tap or ~4s idle.
- Tap cover/title opens `MusicPlayerScreen`.
- Chinese UI only if any new strings appear; prefer icon-only controls matching mini player.
- Do not bump version / create release tags unless the user later says 发布.
- Open work as a PR (or branch commits); do not merge unless asked.

## File map

| File | Responsibility |
|---|---|
| `lib/widgets/music_dynamic_island.dart` | Island UI: collapsed/expanded, ring progress, controls, auto-collapse timer |
| `lib/widgets/main_layout.dart` | Mount island in body `Stack` (top); optional route-visibility helper if kept local |
| `test/music_dynamic_island_test.dart` | Visibility, progress fraction, expand/collapse, control callbacks |
| Spec already on main | Design reference only |

---

### Task 1: Progress math + visibility helpers (TDD)

**Files:**
- Create: `lib/widgets/music_dynamic_island.dart` (pure helpers first, or sibling `lib/music/dynamic_island_logic.dart` if you prefer keeping the widget file UI-only — prefer small top-level functions in `music_dynamic_island.dart` until it grows)
- Test: `test/music_dynamic_island_test.dart`

**Interfaces:**
- Produces:
  - `double musicIslandProgressFraction({required Duration position, required Duration duration})` → `0.0..1.0`, `0` if duration `<= 0`
  - `bool shouldShowMusicIsland({required bool hasCurrentTrack, required bool isOnFullPlayerRoute})` → `hasCurrentTrack && !isOnFullPlayerRoute`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/widgets/music_dynamic_island.dart';

void main() {
  test('progress fraction clamps and handles zero duration', () {
    expect(
      musicIslandProgressFraction(
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 100),
      ),
      0.3,
    );
    expect(
      musicIslandProgressFraction(
        position: const Duration(seconds: 5),
        duration: Duration.zero,
      ),
      0.0,
    );
    expect(
      musicIslandProgressFraction(
        position: const Duration(seconds: 200),
        duration: const Duration(seconds: 100),
      ),
      1.0,
    );
  });

  test('visibility hides on full player', () {
    expect(
      shouldShowMusicIsland(hasCurrentTrack: true, isOnFullPlayerRoute: false),
      isTrue,
    );
    expect(
      shouldShowMusicIsland(hasCurrentTrack: true, isOnFullPlayerRoute: true),
      isFalse,
    );
    expect(
      shouldShowMusicIsland(hasCurrentTrack: false, isOnFullPlayerRoute: false),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/music_dynamic_island_test.dart`
Expected: FAIL (library / functions not found)

- [ ] **Step 3: Minimal implementation**

In `lib/widgets/music_dynamic_island.dart`:

```dart
double musicIslandProgressFraction({
  required Duration position,
  required Duration duration,
}) {
  if (duration <= Duration.zero) return 0.0;
  final value = position.inMilliseconds / duration.inMilliseconds;
  if (value.isNaN) return 0.0;
  return value.clamp(0.0, 1.0);
}

bool shouldShowMusicIsland({
  required bool hasCurrentTrack,
  required bool isOnFullPlayerRoute,
}) {
  return hasCurrentTrack && !isOnFullPlayerRoute;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/music_dynamic_island_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/music_dynamic_island.dart test/music_dynamic_island_test.dart
git commit -m "feat(music): add dynamic island progress and visibility helpers"
```

---

### Task 2: Collapsed capsule + ring progress widget

**Files:**
- Modify: `lib/widgets/music_dynamic_island.dart`
- Test: `test/music_dynamic_island_test.dart`

**Interfaces:**
- Consumes: helpers from Task 1; `MusicPlayerService.instance`; `player.stream.position` / duration (same pattern as `MusicProgressBar` / `MusicLyricsView`)
- Produces: `class MusicDynamicIsland extends StatefulWidget` with collapsed UI only for this task (`expanded` state field can exist but UI may still be collapsed-only until Task 3)

- [ ] **Step 1: Write a widget test for collapsed structure**

```dart
testWidgets('collapsed island shows cover and ring when track present', (tester) async {
  // Arrange MusicPlayerService with a fake/current track if tests already stub it;
  // otherwise pump MusicDynamicIsland with injected progressFraction + title/cover
  // via an optional test constructor / @visibleForTesting parameters.
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: MusicDynamicIsland(debugForceVisible: true, debugProgress: 0.25),
      ),
    ),
  );
  expect(find.byKey(const Key('music_dynamic_island')), findsOneWidget);
  expect(find.byKey(const Key('music_dynamic_island_ring')), findsOneWidget);
});
```

Prefer adding `@visibleForTesting` constructor args `debugForceVisible` / `debugProgress` rather than fighting singleton service setup — keep production path using `MusicPlayerService.instance`.

- [ ] **Step 2: Run test — expect FAIL**

Run: `flutter test test/music_dynamic_island_test.dart`

- [ ] **Step 3: Implement collapsed UI**

Requirements for collapsed look:

- Top-center capsule, dark background, rounded pill
- Left: 28–32px cover via `AuthenticatedImage` (or music_note placeholder)
- Optional short title with ellipsis if width allows; may omit on very small width
- Outer progress: `CustomPaint` or `CircularProgressIndicator`-style arc around the capsule using `musicIslandProgressFraction`
- Keys: `music_dynamic_island`, `music_dynamic_island_ring`
- Subscribe to position stream; `AnimatedBuilder` on `MusicPlayerService` for track metadata
- If `!shouldShowMusicIsland(...)` → `SizedBox.shrink()`

Match existing dark/light feel from mini player (`0xFF1e1e1e` / white patterns) but prefer a compact dark island in both themes unless it clashes badly — follow mini player contrast if needed.

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/music_dynamic_island.dart test/music_dynamic_island_test.dart
git commit -m "feat(music): render collapsed dynamic island with progress ring"
```

---

### Task 3: Expand / collapse + transport

**Files:**
- Modify: `lib/widgets/music_dynamic_island.dart`
- Test: `test/music_dynamic_island_test.dart`

**Interfaces:**
- Produces: expanded layout with IconButtons calling `playPrevious` / `togglePlay` / `playNext`
- Auto-collapse: `Timer(Duration(seconds: 4))` reset on interaction; cancel on dispose

- [ ] **Step 1: Failing tests for expand and controls**

```dart
testWidgets('tap island toggles expanded controls', (tester) async {
  await tester.pumpWidget(/* visible island */);
  expect(find.byKey(const Key('music_island_play')), findsNothing);
  await tester.tap(find.byKey(const Key('music_dynamic_island')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('music_island_play')), findsOneWidget);
});
```

Add keys: `music_island_prev`, `music_island_play`, `music_island_next`.

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement**

- `AnimationController` (~220ms) for width
- Expanded row: prev / play-pause (icon switches on `playing`) / next
- Disable or hide prev when `queueIndex <= 0`; next when `queueIndex >= queue.length - 1` (mirror queue rules in `MusicPlayerService`)
- Tap on cover/title: `Navigator.push` → `MusicPlayerScreen` (same as mini player); do not require expand first
- Tap on non-cover area of capsule: toggle expand
- Start/restart 4s collapse timer whenever expanded and on each control tap
- `Listener` / parent `GestureDetector` for outside tap is handled in Task 4 via layout barrier; for unit test, expose `collapse()` / `expand()` for testing if needed

- [ ] **Step 4: Run — PASS**

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/music_dynamic_island.dart test/music_dynamic_island_test.dart
git commit -m "feat(music): expand dynamic island with playback controls"
```

---

### Task 4: Mount in MainLayout + hide on full player

**Files:**
- Modify: `lib/widgets/main_layout.dart` (body `Stack` near existing `Column` that already includes `MusicMiniPlayer` ~line 343)
- Modify: `lib/widgets/music_dynamic_island.dart` if route detection lives in the widget
- Test: extend `test/music_dynamic_island_test.dart` or add a small route-flag test

**Interfaces:**
- Consumes: `ModalRoute` / `RouteObserver` / simple check: walk navigator for top route `settings.name` or `isCurrent` type — preferred approach for this codebase:

```dart
bool isMusicPlayerRoute(BuildContext context) {
  final route = ModalRoute.of(context);
  // When island is under MainLayout, pushed MusicPlayerScreen is a new route above.
  // Use a RouteObserver registered in MaterialApp, OR check:
  return false; // default when building MainLayout itself
}
```

Practical approach that matches Flutter apps without existing RouteObserver:

1. Register a thin `MusicPlayerRouteTracker` (ChangeNotifier) in `MusicPlayerScreen.initState` / `dispose` (`enter()` / `leave()`).
2. Island reads `MusicPlayerRouteTracker.instance.isActive`.

This avoids brittle route-type sniffing from under `MainLayout`.

**Files for tracker:**
- Create: `lib/services/music_player_route_tracker.dart`
- Modify: `lib/screens/music_player_screen.dart` (call enter/leave)
- Modify: island visibility to use tracker

- [ ] **Step 1: Failing test for tracker**

```dart
test('route tracker flips active flag', () {
  final t = MusicPlayerRouteTracker.instance;
  t.debugReset();
  expect(t.isActive, isFalse);
  t.enter();
  expect(t.isActive, isTrue);
  t.leave();
  expect(t.isActive, isFalse);
});
```

- [ ] **Step 2: Implement tracker + wire MusicPlayerScreen**

```dart
class MusicPlayerRouteTracker extends ChangeNotifier {
  MusicPlayerRouteTracker._();
  static final instance = MusicPlayerRouteTracker._();
  int _depth = 0;
  bool get isActive => _depth > 0;
  void enter() { _depth++; notifyListeners(); }
  void leave() { if (_depth > 0) _depth--; notifyListeners(); }
  @visibleForTesting void debugReset() { _depth = 0; }
}
```

In `MusicPlayerScreen`: `initState` → `enter()`; `dispose` → `leave()`.

- [ ] **Step 3: Mount island**

In `MainLayout` body `Stack` children, add:

```dart
const Positioned(
  top: 0,
  left: 0,
  right: 0,
  child: SafeArea(
    bottom: false,
    child: MusicDynamicIsland(),
  ),
),
```

Ensure it paints above content but does not block the whole screen when collapsed: island widget should size to its capsule (`Center` + intrinsic size) and use `IgnorePointer` on empty areas — wrap so only the capsule hits targets. For outside-tap-to-collapse when expanded, wrap with a full-screen `ModalBarrier`/`GestureDetector` only while `expanded == true` (transparent), on tap → collapse.

- [ ] **Step 4: `flutter test` + analyze touched files**

Run: `flutter test test/music_dynamic_island_test.dart`
Run: `flutter analyze lib/widgets/music_dynamic_island.dart lib/widgets/main_layout.dart lib/services/music_player_route_tracker.dart lib/screens/music_player_screen.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/services/music_player_route_tracker.dart lib/screens/music_player_screen.dart lib/widgets/main_layout.dart lib/widgets/music_dynamic_island.dart test/music_dynamic_island_test.dart
git commit -m "feat(music): mount dynamic island in MainLayout and hide on full player"
```

---

### Task 5: Polish + PR

**Files:**
- Possibly tweak padding so island does not collide with top tabs / Windows title bar — reuse `SafeArea` and existing `WindowsTitleBar` offsets if `MainLayout` already pads for desktop.
- Update design spec status line to “implemented in PR …” only if accurate at PR time.

- [ ] **Step 1: Manual checklist (document in PR body)**

1. Play a track from Music tab → island appears top-center with moving ring  
2. Open full player → island hides; back → island returns  
3. Expand → prev / pause / next work; 4s idle collapses  
4. Bottom mini player still present and functional  
5. Lock screen / notification card still present (Android)  
6. Stop/clear from mini player → island disappears  

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all pass

- [ ] **Step 3: Open PR to `main`**

Title: `feat(music): add Dynamic Island overlay with ring progress`
Body: link spec `docs/superpowers/specs/2026-09-20-selene-dynamic-island-design.md`; note no release/tag.

- [ ] **Step 4: Stop**

Do not merge, do not tag, do not publish. Wait for user.

---

## Spec coverage self-check

| Spec requirement | Task |
|---|---|
| Top floating capsule | 2, 4 |
| Progress ring around capsule | 2 |
| Expand prev/play/next | 3 |
| Collapse outside tap / ~4s | 3, 4 |
| Show with track; hide on full player | 1, 4 |
| Keep mini player + lock screen | 4 (no changes to those modules’ roles) |
| Tap cover → full player | 3 |
| No auto release | 5 |

