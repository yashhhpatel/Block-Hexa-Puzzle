import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/l10n.dart';
import 'progress.dart';

/// Optional "your Daily Puzzle is waiting" notification at 19:00 local
/// time, only on days the daily is still unsolved. A few days are queued
/// ahead so the streak nudge still arrives if the app isn't opened.
class Reminders {
  final Progress progress;
  final bool enabled;
  Reminders(this.progress, {this.enabled = true});

  static const hour = 19;
  static const daysAhead = 3;
  static const _baseId = 4100;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// The days (as local midnights) a reminder should be queued for, given
  /// the time [now] and whether today's daily is [solvedToday].
  static List<DateTime> plan(DateTime now, {required bool solvedToday}) {
    final days = <DateTime>[];
    for (var i = 0; i < daysAhead; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      if (i == 0 && (solvedToday || now.hour >= hour)) continue;
      days.add(d);
    }
    return days;
  }

  Future<bool> _init() async {
    if (!enabled) return false;
    if (_ready) return true;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Reminders: time zone unavailable ($e)');
      tz.setLocalLocation(tz.UTC);
    }
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Reminders: init failed ($e)');
    }
    return _ready;
  }

  /// Asks Android 13+ for permission to post notifications.
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    await progress.setReminderAsked();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Rebuilds the queue from the current settings and daily progress.
  /// Called at start-up, after a daily solve and when the setting changes.
  Future<void> reschedule() async {
    if (!await _init()) return;
    try {
      for (var i = 0; i < daysAhead + 1; i++) {
        await _plugin.cancel(id: _baseId + i);
      }
      if (!progress.remindersOn) return;
      final now = DateTime.now();
      final days = plan(now, solvedToday: progress.isDailySolved(progress.today));
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily Puzzle',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );
      for (var i = 0; i < days.length; i++) {
        final d = days[i];
        await _plugin.zonedSchedule(
          id: _baseId + i,
          title: tr('notif_title'),
          body: tr('notif_body'),
          scheduledDate: tz.TZDateTime(tz.local, d.year, d.month, d.day, hour),
          notificationDetails: details,
          // Inexact: no exact-alarm permission needed, a few minutes late is fine.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Reminders: scheduling failed ($e)');
    }
  }

  /// After the first daily solve, ask once for permission so the streak
  /// reminder can work, then refresh the queue.
  Future<void> afterDailySolved() async {
    if (!enabled) return;
    if (progress.remindersOn && !progress.reminderAsked) {
      await requestPermission();
    }
    await reschedule();
  }
}
