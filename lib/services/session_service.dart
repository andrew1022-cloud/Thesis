import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'connectivity_service.dart';
import 'notification_service.dart';
import 'remember_me_service.dart';

/// SessionService
/// --------------
/// One place that fully signs the user out, used by both the student
/// (ProfileScreen) and admin (AdminScreen) log-out buttons.
///
/// Every step is isolated and time-limited, so one failing or hanging
/// step (e.g. the notifications plugin) can never stop the Firebase
/// sign-out from happening.
///
/// Order matters:
///  1. Clear the "Remember Me" flags (so a stale admin flag can't
///     route the next user to the admin screen while offline).
///  2. Sign out of Google (otherwise the account picker silently
///     re-selects the previous Google account).
///  3. Sign out of Firebase. After this, `currentUser` is null, which
///     is what HomeController checks before scheduling reminders.
///  4. Cancel every scheduled notification (done AFTER sign-out so a
///     reminder that was being scheduled can't slip in behind it).
///  5. Stop the connectivity listener.
class SessionService {
  SessionService._internal();
  static final SessionService instance = SessionService._internal();

  static const Duration _stepTimeout = Duration(seconds: 4);

  Future<void> logout() async {
    await _step('clear remember-me', () => RememberMeService.instance.clear());
    await _step('google sign-out', () => GoogleSignIn().signOut());

    // The one step that must succeed — it is intentionally not wrapped
    // in _step, so a real failure is visible to the caller.
    await FirebaseAuth.instance.signOut();

    await _step(
        'cancel notifications', () => NotificationService.instance.cancelAll());
    try {
      ConnectivityService.instance.stop();
    } catch (e) {
      debugPrint('SessionService: connectivity stop failed: $e');
    }
  }

  Future<void> _step(String name, Future<void> Function() action) async {
    try {
      await action().timeout(_stepTimeout);
    } catch (e) {
      debugPrint('SessionService: "$name" failed during logout: $e');
    }
  }
}
