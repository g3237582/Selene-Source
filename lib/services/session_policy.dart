/// Outcomes of a cookie / password re-login attempt.
enum SessionRefreshOutcome {
  success,
  rejected,
  networkError,
  serverError,
}

/// What the API layer should do after a 401.
enum SessionRecoveryAction {
  retryAfterRefresh,
  keepSession,
  logout,
}

/// Pure session rules used by startup and 401 handling.
class SessionPolicy {
  /// Keep the user on the home screen when cookies are already persisted.
  ///
  /// A previous implementation required a successful network re-login on every
  /// launch, so a transient outage looked like a logout.
  static bool shouldEnterHomeWithoutNetwork({
    required bool keepLoggedIn,
    required bool hasCookies,
  }) {
    return keepLoggedIn && hasCookies;
  }

  /// Re-login only when keep-login is on and there is no usable cookie yet.
  static bool shouldAttemptAutoLogin({
    required bool keepLoggedIn,
    required bool hasCredentials,
    required bool hasCookies,
  }) {
    return keepLoggedIn && hasCredentials && !hasCookies;
  }

  static bool shouldRefreshOnUnauthorized({
    required bool keepLoggedIn,
    required bool hasCredentials,
  }) {
    return keepLoggedIn && hasCredentials;
  }

  static SessionRecoveryAction decideAfterRefresh(
    SessionRefreshOutcome outcome,
  ) {
    switch (outcome) {
      case SessionRefreshOutcome.success:
        return SessionRecoveryAction.retryAfterRefresh;
      case SessionRefreshOutcome.rejected:
        return SessionRecoveryAction.logout;
      case SessionRefreshOutcome.networkError:
      case SessionRefreshOutcome.serverError:
        return SessionRecoveryAction.keepSession;
    }
  }

  static SessionRecoveryAction decideWithoutRefresh({
    required bool keepLoggedIn,
  }) {
    return SessionRecoveryAction.logout;
  }
}
