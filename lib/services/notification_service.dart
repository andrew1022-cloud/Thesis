import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// One scheduled reminder's copy.
class _ReminderCopy {
  final String title;
  final String body;
  const _ReminderCopy({required this.title, required this.body});
}

/// NotificationService
/// -------------------
/// Local, on-device "come back and review" reminders — the same idea
/// as Duolingo's streak-loss notifications. Nothing here talks to a
/// server: every time the user opens the app, this reschedules a
/// fixed ladder of reminders (1, 2, 3, 5, 7, 14 days from now) that
/// only actually fire if the user *doesn't* open the app again before
/// then, because opening the app cancels and reschedules the whole
/// ladder from scratch.
///
/// Add to pubspec.yaml:
///   dependencies:
///     flutter_local_notifications: ^18.0.1
///     flutter_timezone: ^1.0.8
///     timezone: ^0.9.4
///
/// Android also needs a couple of manifest entries — see
/// NOTIFICATION_SETUP.md for the exact snippet.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Reserved id range for inactivity reminders so scheduling/
  /// cancelling them never collides with other notification types
  /// you might add later (e.g. calendar event reminders).
  static const int _inactivityIdBase = 5000;

  /// Id used by [scheduleTestNotification] — kept well outside the
  /// inactivity range above.
  static const int _testNotificationId = 9999;

  static const String _channelId = 'inactivity_reminders';
  static const String _channelName = 'Review Reminders';
  static const String _channelDescription =
      "Reminders to come back and review when you haven't opened "
      'RevEduc in a while.';

  /// Days-since-last-open → what the notification says. Escalates
  /// from a light nudge to a more direct one, the same shape as
  /// Duolingo's streak reminders. Edit freely — add/remove day
  /// offsets or change the copy without touching anything else.
  static const Map<int, _ReminderCopy> _inactivitySchedule = {
    1: _ReminderCopy(
      title: "Don't lose your streak! 🔥",
      body: "You haven't reviewed today. Jump back in to keep it alive.",
    ),
    2: _ReminderCopy(
      title: 'We miss you at RevEduc 👋',
      body: "It's been 2 days. A quick 5-minute review keeps things fresh.",
    ),
    3: _ReminderCopy(
      title: '3 days and counting...',
      body: 'Your competencies are waiting. Come back and pick up where '
          'you left off.',
    ),
    5: _ReminderCopy(
      title: 'Your LET prep needs you 📚',
      body: "It's been 5 days since your last review. Every session "
          'counts toward exam day.',
    ),
    7: _ReminderCopy(
      title: 'A whole week away!',
      body: "Don't let a week turn into a habit. Open RevEduc and "
          'review just one lesson today.',
    ),
    14: _ReminderCopy(
      title: 'Still preparing for the LET?',
      body: "It's been 2 weeks since your last review. Let's get your "
          'prep back on track.',
    ),
  };

  /// Call once at app startup (see main.dart). Safe to call more than
  /// once — subsequent calls are no-ops.
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Falls back to UTC — reminders still fire, just anchored to
      // UTC clock time instead of the device's local time.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  /// Prompts for notification permission. Safe to call repeatedly —
  /// on Android it silently returns the current status after the
  /// first prompt; on iOS the system only ever shows the dialog once
  /// per install regardless of how many times this is called.
  /// Returns true if permission is granted (or already was).
  Future<bool> requestPermission() async {
    if (!_initialized) await init();

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      return await androidImpl.requestNotificationsPermission() ?? true;
    }
    if (iosImpl != null) {
      return await iosImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
    }
    return true;
  }

  /// Resets the inactivity-reminder ladder: cancels whatever was
  /// scheduled before and schedules a fresh one counting forward from
  /// [from] (defaults to now). Call this every time the user opens
  /// the app / lands on Home — see HomeController.loadDashboard.
  ///
  /// [hour]/[minute] control what local time each reminder fires at
  /// (default 6:00 PM), so the "day 3" reminder fires at 6 PM three
  /// days after [from], not at whatever time-of-day the app happened
  /// to be opened.
  Future<void> scheduleInactivityReminders({
    DateTime? from,
    int hour = 18,
    int minute = 0,
  }) async {
    if (!_initialized) await init();

    await cancelInactivityReminders();

    final baseDate = from ?? DateTime.now();
    final now = DateTime.now();

    for (final entry in _inactivitySchedule.entries) {
      final dayOffset = entry.key;
      final copy = entry.value;

      final target = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day + dayOffset,
        hour,
        minute,
      );

      // Guards against scheduling something already in the past (e.g.
      // clock changes, or this being called late in the day) —
      // flutter_local_notifications throws if you schedule for a past
      // time.
      if (!target.isAfter(now)) continue;

      await _plugin.zonedSchedule(
        _inactivityIdBase + dayOffset,
        copy.title,
        copy.body,
        tz.TZDateTime.from(target, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Cancels every pending inactivity reminder. Called automatically
  /// at the start of [scheduleInactivityReminders]; expose it
  /// separately in case you want to silence reminders entirely (e.g.
  /// a "Reminders" toggle in Settings).
  Future<void> cancelInactivityReminders() async {
    for (final dayOffset in _inactivitySchedule.keys) {
      await _plugin.cancel(_inactivityIdBase + dayOffset);
    }
  }

  /// Cancels absolutely everything this plugin instance has scheduled
  /// — use on full logout if you don't want a signed-out device to
  /// still nag about a review streak.
  Future<void> cancelAll() => _plugin.cancelAll();

  /// Dev/debug helper — fires a single test notification 10 seconds
  /// from now, so you can verify permissions, the notification
  /// channel, and appearance without waiting days for the real
  /// reminders. Not called anywhere by default; wire it to a button
  /// in a debug-only menu (see ProfileScreen's Developer Tools).
  Future<void> scheduleTestNotification() async {
    if (!_initialized) await init();
    await requestPermission();

    final target =
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));

    try {
      await _plugin.zonedSchedule(
        _testNotificationId,
        'Test reminder',
        'If you can see this, notifications are wired up correctly.',
        target,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService: test notification failed: $e');
      rethrow;
    }
  }
}
