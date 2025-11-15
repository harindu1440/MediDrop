import '../firebase_operations.dart';
import 'notifications_service.dart';

class MedicineNotificationHandler {
  static final MedicineNotificationHandler _instance =
      MedicineNotificationHandler._internal();

  factory MedicineNotificationHandler() {
    return _instance;
  }

  MedicineNotificationHandler._internal();

  /// Check for missed medicines and notify
  /// Call this periodically to detect missed medicines
  Future<void> checkMissedMedicines() async {
    try {
      final medicines = await FirebaseOperations.readData('medicines');
      if (medicines == null || medicines is! Map) return;

      final now = DateTime.now();

      for (var entry in medicines.entries) {
        final medicineData = entry.value as Map;
        final medicineName = medicineData['name'] ?? '';
        final medicineDosage = medicineData['dosage'] ?? '';
        final medicineTime = medicineData['time'] ?? '';
        final isTaken = medicineData['isTaken'] ?? false;

        // Parse medicine time
        final medicineTimeData = _parseTime(medicineTime);
        if (medicineTimeData == null) continue;

        final medicineHour = medicineTimeData['hour'] as int;
        final medicineMinute = medicineTimeData['minute'] as int;

        // Check if current time is past medicine time and medicine not taken
        final medicineDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          medicineHour,
          medicineMinute,
        );

        // If current time is more than 10 minutes past medicine time and not taken
        if (now.isAfter(medicineDateTime.add(const Duration(minutes: 10))) &&
            !isTaken) {
          // Only show notification if not shown before today
          final notificationsDb = await FirebaseOperations.readData(
            'notifications',
          );
          bool alreadyNotified = false;

          if (notificationsDb != null && notificationsDb is Map) {
            alreadyNotified = notificationsDb.values.whereType<Map>().any(
              (n) =>
                  n['medicineName'] == medicineName &&
                  n['type'] == 'missed_medicine' &&
                  n['timestamp'].toString().contains(
                    now.toIso8601String().split('T')[0],
                  ),
            );
          }

          if (!alreadyNotified) {
            print(
              '⚠️ Missed medicine detected: $medicineName at $medicineTime',
            );
            await NotificationsService().showMissedMedicineNotification(
              medicineName,
              medicineDosage,
              medicineTime,
            );
          }
        }
      }
    } catch (e) {
      print('Error checking missed medicines: $e');
    }
  }

  /// Schedule reminder 1 minute before medicine time
  Future<void> scheduleAdvanceReminder(
    String medicineName,
    String medicineDosage,
    String medicineTime,
  ) async {
    try {
      final timeData = _parseTime(medicineTime);
      if (timeData == null) return;

      final hour = timeData['hour'] as int;
      final minute = timeData['minute'] as int;

      // Calculate 1 minute before
      var advanceHour = hour;
      var advanceMinute = minute - 1;

      if (advanceMinute < 0) {
        advanceMinute += 60;
        advanceHour -= 1;
        if (advanceHour < 0) {
          advanceHour = 23;
        }
      }

      print(
        '⏰ Scheduling advance reminder for $medicineName at $advanceHour:${advanceMinute.toString().padLeft(2, '0')}',
      );

      await NotificationsService().showAdvanceReminder(
        medicineName,
        medicineDosage,
        medicineTime,
      );
    } catch (e) {
      print('Error scheduling advance reminder: $e');
    }
  }

  /// Schedule reminder at exact medicine time
  Future<void> scheduleMedicineReminder(
    String medicineName,
    String medicineDosage,
    String medicineTime,
  ) async {
    try {
      final timeData = _parseTime(medicineTime);
      if (timeData == null) return;

      print(
        '💊 Scheduling medicine reminder for $medicineName at $medicineTime',
      );

      await NotificationsService().showMedicineReminder(
        medicineName,
        medicineDosage,
        medicineTime,
      );
    } catch (e) {
      print('Error scheduling medicine reminder: $e');
    }
  }

  /// Parse time string "HH:MM AM/PM" to hour and minute
  Map<String, int>? _parseTime(String timeString) {
    try {
      final parts = timeString.split(' ');
      if (parts.length != 2) return null;

      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;

      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();

      // Convert to 24-hour format
      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      return {'hour': hour, 'minute': minute};
    } catch (e) {
      print('Error parsing time: $timeString - $e');
      return null;
    }
  }
}
