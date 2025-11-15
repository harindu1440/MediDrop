import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../firebase_operations.dart';

class NotificationsService {
  static final NotificationsService _instance =
      NotificationsService._internal();

  factory NotificationsService() {
    return _instance;
  }

  NotificationsService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  /// Show immediate medicine reminder (at exact time)
  Future<void> showMedicineReminder(
    String medicineName,
    String dosage,
    String scheduledTime,
  ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'medicine_reminder_channel',
          'Medicine Reminders',
          channelDescription: 'Notifications for medicine reminders',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final int notifId = _idFromString('$medicineName|$scheduledTime|medicine');
    await flutterLocalNotificationsPlugin.show(
      notifId,
      '💊 Medicine Reminder',
      'Time to take $medicineName ($dosage) at $scheduledTime',
      platformChannelSpecifics,
      payload: medicineName,
    );

    // Write to database (store localId so it can be cancelled later)
    await _saveNotificationToDatabase(
      'medicine_reminder',
      '💊 Medicine Reminder',
      'Time to take $medicineName ($dosage) at $scheduledTime',
      localId: notifId,
      medicineName: medicineName,
      scheduledDate: DateTime.now().toIso8601String(),
    );
  }

  /// Show advance reminder (1 minute before medicine time)
  Future<void> showAdvanceReminder(
    String medicineName,
    String dosage,
    String scheduledTime,
  ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'advance_reminder_channel',
          'Advance Reminders',
          channelDescription: 'Advance notifications before medicine time',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // Use a deterministic id so the same advance reminder doesn't stack
    final int notifId = _idFromString('$medicineName|$scheduledTime|advance');
    await flutterLocalNotificationsPlugin.show(
      notifId,
      '⏰ Medicine Alert',
      '$medicineName ($dosage) reminder in 1 minute at $scheduledTime',
      platformChannelSpecifics,
      payload: medicineName,
    );

    // Write to database (store localId)
    await _saveNotificationToDatabase(
      'advance_reminder',
      '⏰ Medicine Alert',
      '$medicineName ($dosage) - get ready, reminder in 1 minute',
      localId: notifId,
      medicineName: medicineName,
      scheduledDate: DateTime.now().toIso8601String(),
    );
  }

  /// Show missed medicine notification
  Future<void> showMissedMedicineNotification(
    String medicineName,
    String dosage,
    String scheduledTime,
  ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'missed_medicine_channel',
          'Missed Medicines',
          channelDescription: 'Notifications for missed medicines',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // Use a deterministic id per-day so missed notifications don't duplicate for the same day
    final dayKey = DateTime.now().toIso8601String().split('T').first;
    final int notifId = _idFromString(
      '$medicineName|$scheduledTime|missed|$dayKey',
    );
    await flutterLocalNotificationsPlugin.show(
      notifId,
      '⚠️ Missed Medicine Alert',
      'You missed $medicineName ($dosage) at $scheduledTime',
      platformChannelSpecifics,
      payload: medicineName,
    );

    // Write to database (store localId)
    await _saveNotificationToDatabase(
      'missed_medicine',
      '⚠️ Missed Medicine Alert',
      'You missed $medicineName ($dosage) at $scheduledTime',
      localId: notifId,
      medicineName: medicineName,
      scheduledDate: DateTime.now().toIso8601String(),
    );
  }

  /// Save notification to Firebase database and return the DB key.
  /// If `localId` is provided it will be stored so callers can cancel a specific local notification.
  Future<String?> _saveNotificationToDatabase(
    String type,
    String title,
    String message, {
    int? localId,
    String? medicineName,
    String? scheduledDate,
  }) async {
    try {
      final notificationData = {
        'type': type,
        'title': title,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        if (localId != null) 'localId': localId,
        if (medicineName != null) 'medicineName': medicineName,
        if (scheduledDate != null) 'scheduledDate': scheduledDate,
      };

      // If a localId is provided, try to find an existing DB entry with same localId
      if (localId != null) {
        final existing = await FirebaseOperations.readData('notifications');
        if (existing != null && existing is Map) {
          for (var entry in existing.entries) {
            final key = entry.key;
            final value = entry.value;
            if (value is Map) {
              try {
                if (value['localId'] == localId) {
                  await FirebaseOperations.writeData(
                    'notifications/$key',
                    notificationData,
                  );
                  print('✓ Updated existing notification in DB: $key');
                  return key;
                }
              } catch (_) {}
            }
          }
        }
      }

      final notificationId = DateTime.now().millisecondsSinceEpoch.toString();
      await FirebaseOperations.writeData(
        'notifications/$notificationId',
        notificationData,
      );
      print('✓ Notification saved to database: $type ($notificationId)');
      return notificationId;
    } catch (e) {
      print('Error saving notification to database: $e');
      return null;
    }
  }

  /// Schedule daily medicine reminder (at exact time)
  Future<void> scheduleDaily(
    int id,
    String medicineName,
    String dosage,
    String timeString, // Format: "09:00 AM"
  ) async {
    try {
      // Parse time string (e.g., "09:00 AM")
      final timeParts = timeString.split(' ');
      final hourMinute = timeParts[0].split(':');
      int hour = int.parse(hourMinute[0]);
      final minute = int.parse(hourMinute[1]);

      // Adjust for PM
      if (timeParts[1] == 'PM' && hour != 12) {
        hour += 12;
      } else if (timeParts[1] == 'AM' && hour == 12) {
        hour = 0;
      }

      final tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'medicine_reminder_channel',
            'Medicine Reminders',
            channelDescription: 'Notifications for medicine reminders',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      // Schedule main reminder at exact time
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        '💊 Medicine Reminder',
        'Time to take $medicineName ($dosage)',
        scheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // Schedule advance reminder 1 minute before
      final advanceReminderTime = scheduledDate.subtract(
        const Duration(minutes: 1),
      );
      const AndroidNotificationDetails advanceAndroidSpecifics =
          AndroidNotificationDetails(
            'advance_reminder_channel',
            'Advance Reminders',
            channelDescription: 'Advance notifications before medicine time',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          );

      const NotificationDetails advancePlatformSpecifics = NotificationDetails(
        android: advanceAndroidSpecifics,
      );

      final int advanceId = id + 10000; // Different ID for advance reminder

      await flutterLocalNotificationsPlugin.zonedSchedule(
        advanceId,
        '⏰ Medicine Alert',
        '$medicineName ($dosage) - get ready, reminder in 1 minute',
        advanceReminderTime,
        advancePlatformSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // Save DB entries for both scheduled notifications (store local ids)
      await _saveNotificationToDatabase(
        'medicine_reminder',
        '💊 Medicine Reminder',
        'Time to take $medicineName ($dosage) at $timeString',
        localId: id,
        medicineName: medicineName,
        scheduledDate: scheduledDate.toIso8601String(),
      );

      await _saveNotificationToDatabase(
        'advance_reminder',
        '⏰ Medicine Alert',
        '$medicineName ($dosage) - get ready, reminder in 1 minute',
        localId: advanceId,
        medicineName: medicineName,
        scheduledDate: advanceReminderTime.toIso8601String(),
      );

      print('✓ Scheduled notifications for $medicineName:');
      print('  - Main reminder at $timeString (id: $id)');
      print('  - Advance reminder 1 minute before (id: $advanceId)');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Deterministic positive int id from a string (safe for notification ids)
  int _idFromString(String s) {
    return s.hashCode & 0x7fffffff;
  }

  /// Clear a saved notification record and optionally cancel the local notification
  ///
  /// - `notificationId`: the database key under `notifications/{id}` (string)
  /// - `localId`: optional local notification id to cancel (e.g. scheduled id or immediate id)
  Future<void> clearNotification(String notificationId, {int? localId}) async {
    try {
      // If localId not provided, try to read it from the DB entry
      int? idToCancel = localId;
      if (idToCancel == null) {
        final entry = await FirebaseOperations.readData(
          'notifications/$notificationId',
        );
        if (entry != null && entry is Map && entry['localId'] != null) {
          try {
            idToCancel = (entry['localId'] as num).toInt();
          } catch (_) {
            idToCancel = null;
          }
        }
      }

      if (idToCancel != null) {
        await cancelNotification(idToCancel);
        print('✓ Local notification cancelled: $idToCancel');
      }

      await FirebaseOperations.deleteData('notifications/$notificationId');
      print('✓ Notification cleared from database: $notificationId');
    } catch (e) {
      print('Error clearing notification $notificationId: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
