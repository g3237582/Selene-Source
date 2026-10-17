import 'special_source_access.dart';

/// Video-search source mode. Default is normal. Special is opt-in and only
/// visible after a capability check says `available`.
class VideoSearchModeState {
  bool special = false;
  bool toggleVisible = false;
  String? notice;

  void applyCapability(SpecialSourceCapability capability) {
    toggleVisible = capability.showToggle;
    if (!toggleVisible) {
      special = false;
    }
  }

  /// Drop the previous server's toggle until the new login is checked.
  void onSessionChanged() {
    toggleVisible = false;
    special = false;
    notice = null;
  }

  /// Hide the toggle, leave special mode, and ask the caller to re-run in
  /// normal mode when a special search was in progress.
  bool onSpecialForbidden() {
    final rerun = special;
    special = false;
    toggleVisible = false;
    notice = SpecialSourceForbiddenException.message;
    return rerun;
  }
}
