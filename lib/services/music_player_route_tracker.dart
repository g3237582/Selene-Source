import 'package:flutter/foundation.dart';

class MusicPlayerRouteTracker extends ChangeNotifier {
  MusicPlayerRouteTracker._();

  static final instance = MusicPlayerRouteTracker._();

  int _depth = 0;

  bool get isActive => _depth > 0;

  void enter() {
    _depth++;
    notifyListeners();
  }

  void leave() {
    if (_depth > 0) {
      _depth--;
    }
    notifyListeners();
  }

  @visibleForTesting
  void debugReset() {
    _depth = 0;
  }
}
