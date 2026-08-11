import 'dart:async';

import 'package:flutter/material.dart';

import 'session.dart';

class ApiSessionExpiredBinder {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final Map<RiderSession, StreamSubscription<bool>> _subs = {};

  static void bind(RiderSession session) {
    _subs[session]?.cancel();
    _subs[session] = session.api.sessionExpired.listen((_) {
      // RootRouter reacts to `loggedIn` and swaps to the login screen.
      session.signOut();
    });
  }
}
