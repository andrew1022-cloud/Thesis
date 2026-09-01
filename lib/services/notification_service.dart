import 'dart:typed_data' show Int64List, Uint8List;
import 'dart:ui' show Color;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Brand colors, duplicated here (rather than importing home_widgets.dart)
/// so this service has zero dependency on the widget layer.
const Color _kMaroon = Color(0xFF6E1B24);
const Color _kGold = Color(0xFFC9A24B);

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
/// Notifications are styled to match RevEduc's brand: a maroon accent
/// color, an expandable "big text" body so the full message is
/// readable without opening the app, and the app's launcher icon as
/// both the small and large icon.
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

  /// The real RevEduc logo, decoded once from assets and reused as
  /// the large icon on every notification. Unlike the status-bar
  /// small icon, Android does NOT flatten the large icon to a
  /// silhouette — it renders full color, so this is what actually
  /// makes a notification look "branded" rather than generic.
  Uint8List? _logoBytes;
  ui.Image? _logoImage;

  /// Rendered notification-card PNGs, keyed by "title|body" so the
  /// same reminder text isn't re-rendered every time the ladder is
  /// rescheduled (which happens on every app open).
  final Map<String, Uint8List> _cardCache = {};

  Future<Uint8List> _loadLogoBytes() async {
    if (_logoBytes != null) return _logoBytes!;
    final data = await rootBundle.load('assets/images/logo.png');
    _logoBytes = data.buffer.asUint8List();
    return _logoBytes!;
  }

  Future<AndroidBitmap<Object>> _resolveLargeIcon() async {
    try {
      return ByteArrayAndroidBitmap(await _loadLogoBytes());
    } catch (e) {
      debugPrint('NotificationService: failed to load logo asset: $e');
      // Falls back to the (flattened, monochrome) launcher icon rather
      // than showing no large icon at all.
      return const DrawableResourceAndroidBitmap('@mipmap/ic_launcher');
    }
  }

  Future<ui.Image?> _resolveLogoImage() async {
    if (_logoImage != null) return _logoImage;
    try {
      _logoImage = await decodeImageFromList(await _loadLogoBytes());
      return _logoImage;
    } catch (e) {
      debugPrint('NotificationService: failed to decode logo image: $e');
      return null;
    }
  }

  /// Renders the fully custom "expanded" notification card as a PNG:
  /// maroon background, the real app logo in a badge, a Georgia
  /// title, and a Roboto body — matching the in-app maroon cards
  /// pixel-for-pixel, which a plain system notification can't do.
  Future<Uint8List> _renderNotificationCard({
    required String title,
    required String body,
  }) async {
    final cacheKey = '$title|$body';
    final cached = _cardCache[cacheKey];
    if (cached != null) return cached;

    const double width = 1000;
    const double height = 500;
    const double padding = 48;
    const double badgeSize = 96;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      const ui.Rect.fromLTWH(0, 0, width, height),
    );

    // Background.
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, width, height),
      ui.Paint()..color = _kMaroon,
    );

    // Logo badge — translucent white circle with the real logo inside.
    final badgeCenter =
        const ui.Offset(padding + badgeSize / 2, padding + badgeSize / 2);
    canvas.drawCircle(
      badgeCenter,
      badgeSize / 2,
      ui.Paint()..color = const Color(0x26FFFFFF),
    );

    final logoImage = await _resolveLogoImage();
    if (logoImage != null) {
      final logoSize = badgeSize * 0.62;
      canvas.save();
      canvas.clipPath(
        ui.Path()
          ..addOval(ui.Rect.fromCircle(center: badgeCenter, radius: badgeSize / 2)),
      );
      canvas.drawImageRect(
        logoImage,
        ui.Rect.fromLTWH(
            0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
        ui.Rect.fromCenter(
            center: badgeCenter, width: logoSize, height: logoSize),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      canvas.restore();
    }

    // "REVEDUC" wordmark next to the badge.
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'REVEDUC',
        style: TextStyle(
          color: _kGold,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      ui.Offset(
        padding + badgeSize + 20,
        padding + (badgeSize - labelPainter.height) / 2,
      ),
    );

    // Title — Georgia, matching in-app headings.
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 40,
          fontWeight: FontWeight.bold,
          fontFamily: 'Georgia',
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: width - padding * 2);
    final titleTop = padding + badgeSize + 24;
    titlePainter.paint(canvas, ui.Offset(padding, titleTop));

    // Body — Roboto (app default).
    final bodyPainter = TextPainter(
      text: TextSpan(
        text: body,
        style: const TextStyle(
          color: Color(0xD9FFFFFF), // white @ 85%
          fontSize: 26,
          fontFamily: 'Roboto',
          height: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: width - padding * 2);
    bodyPainter.paint(
      canvas,
      ui.Offset(padding, titleTop + titlePainter.height + 14),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    _cardCache[cacheKey] = bytes;
    return bytes;
  }

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

    // High importance + lights/vibration so the channel itself carries
    // the "premium" feel, not just each individual notification.
    final androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      enableLights: true,
      ledColor: _kGold,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(const [0, 250, 150, 250]),
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

  /// Builds the branded notification details shared by every reminder:
  /// a maroon-tinted Android notification carrying the real RevEduc
  /// logo as its large icon, with an expandable "big text" body, plus
  /// an iOS variant with a matching subtitle and sound.
  ///
  /// Note on `color`: Android only paints a full colored *background*
  /// (what `colorized` does) on notifications tied to a call, a media
  /// session, or a foreground service — a plain reminder like this one
  /// isn't eligible, so the system silently ignores that flag. `color`
  /// on its own still tints the app-name text and expand affordance on
  /// most launchers (Pixel, One UI, etc.), which is the most Android
  /// allows here without a fully custom notification layout.
  Future<NotificationDetails> _brandedDetails({
    required String title,
    required String body,
  }) async {
    final largeIcon = await _resolveLargeIcon();
    final cardBytes = await _renderNotificationCard(title: title, body: body);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      color: _kMaroon,
      icon: '@mipmap/ic_launcher',
      largeIcon: largeIcon,
      styleInformation: BigPictureStyleInformation(
        ByteArrayAndroidBitmap(cardBytes),
        largeIcon: largeIcon,
        hideExpandedLargeIcon: true,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
        summaryText: 'RevEduc',
        htmlFormatSummaryText: false,
      ),
      ticker: title,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      enableLights: true,
      ledColor: _kGold,
      ledOnMs: 800,
      ledOffMs: 800,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(const [0, 250, 150, 250]),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'RevEduc',
      sound: 'default',
      interruptionLevel: InterruptionLevel.active,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
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
        await _brandedDetails(title: copy.title, body: copy.body),
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

  /// Dev/debug helper — fires a single test notification immediately,
  /// so tapping its button in the UI shows the styled notification
  /// right away instead of making you wait and check the tray blind.
  /// Not called anywhere by default; wire it to a button in a
  /// debug-only menu (see ProfileScreen's Developer Tools).
  Future<void> scheduleTestNotification() async {
    if (!_initialized) await init();
    await requestPermission();

    const title = 'Test reminder';
    const body =
        'If you can see this styled nicely — maroon accent, big-text '
        'body, large icon — notifications are wired up correctly.';

    try {
      await _plugin.show(
        _testNotificationId,
        title,
        body,
        await _brandedDetails(title: title, body: body),
      );
    } catch (e) {
      debugPrint('NotificationService: test notification failed: $e');
      rethrow;
    }
  }
}
