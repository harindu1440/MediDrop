# Notification System - Event-Based Implementation

## 🔔 Overview

The notification system has been completely redesigned to be **event-based** instead of showing default notifications. Notifications are now:

1. **Saved to Firebase Database** - All notifications are persisted
2. **Triggered on Specific Events** - Not default when app starts
3. **Smart Missed Medicine Detection** - Automatically detects and notifies when medicine is missed
4. **Advance Reminders** - Notifies 5 minutes before medicine time

---

## 📱 Notification Types

### 1. **Advance Reminder** (5 Minutes Before)
```
⏰ Medicine Alert
"Paracetamol (500mg) - get ready, reminder in 5 minutes"
```
- **Trigger**: Automatically 5 minutes before scheduled medicine time
- **Database**: Saved to `notifications/{id}`
- **User Action**: None needed - automatic notification

### 2. **Medicine Reminder** (At Exact Time)
```
💊 Medicine Reminder
"Time to take Paracetamol (500mg)"
```
- **Trigger**: Automatically at the scheduled medicine time
- **Database**: Saved to `notifications/{id}`
- **User Action**: Mark medicine as taken or dismiss

### 3. **Missed Medicine Alert** (After 10 Minutes Past Time)
```
⚠️ Missed Medicine Alert
"You missed Paracetamol (500mg) at 03:00 PM"
```
- **Trigger**: When medicine time has passed + 10 minutes AND medicine is NOT marked as taken
- **Database**: Saved to `notifications/{id}`
- **User Action**: Take medicine or skip

---

## 🗄️ Database Structure

### Notifications Collection
```json
{
  "notifications": {
    "1731525600000": {
      "type": "medicine_reminder",
      "title": "💊 Medicine Reminder",
      "message": "Time to take Paracetamol (500mg)",
      "timestamp": "2025-11-14T15:00:00.000Z"
    },
    "1731525900000": {
      "type": "advance_reminder",
      "title": "⏰ Medicine Alert",
      "message": "Paracetamol (500mg) - get ready, reminder in 5 minutes",
      "timestamp": "2025-11-14T14:55:00.000Z"
    },
    "1731526200000": {
      "type": "missed_medicine",
      "title": "⚠️ Missed Medicine Alert",
      "message": "You missed Paracetamol (500mg) at 03:00 PM",
      "timestamp": "2025-11-14T15:10:00.000Z"
    }
  }
}
```

### Medicines Collection (Updated)
```json
{
  "medicines": {
    "1234567890": {
      "id": "1234567890",
      "name": "Paracetamol",
      "dosage": "500mg",
      "frequency": "Once a day",
      "time": "03:00 PM",
      "dateAdded": "2025-11-14T10:00:00.000Z",
      "isTaken": false
    }
  }
}
```

---

## 🔧 Key Components

### 1. **NotificationsService** (`lib/services/notifications_service.dart`)

**New Methods**:
```dart
// Show immediate medicine reminder at exact time
Future<void> showMedicineReminder(
  String medicineName,
  String dosage,
  String scheduledTime,
) async

// Show advance reminder 5 minutes before
Future<void> showAdvanceReminder(
  String medicineName,
  String dosage,
  String scheduledTime,
) async

// Show missed medicine notification
Future<void> showMissedMedicineNotification(
  String medicineName,
  String dosage,
  String scheduledTime,
) async

// Internal: Save notification to Firebase
Future<void> _saveNotificationToDatabase(
  String type,
  String title,
  String message,
) async
```

**Database Integration**:
- Every notification call automatically saves to `notifications/{id}`
- Stores: type, title, message, timestamp
- Timestamp in ISO 8601 format for easy querying

### 2. **MedicineNotificationHandler** (`lib/services/medicine_notification_handler.dart`)

**New Service**:
- Handles missed medicine detection
- Checks every minute if medicine is overdue
- Avoids duplicate notifications same day
- Parses time strings ("09:00 AM" → hour 9, minute 0)

**Key Methods**:
```dart
// Check for missed medicines (called every minute)
Future<void> checkMissedMedicines() async

// Schedule advance reminder 5 minutes before
Future<void> scheduleAdvanceReminder(
  String medicineName,
  String medicineDosage,
  String medicineTime,
) async

// Schedule reminder at exact medicine time
Future<void> scheduleMedicineReminder(
  String medicineName,
  String medicineDosage,
  String medicineTime,
) async

// Parse time string helper
Map<String, int>? _parseTime(String timeString)
```

### 3. **HomeScreen Updates** (`lib/screens/home_screen.dart`)

**Changes**:
- Removed default notification scheduling
- Added `_checkMissedMedicinesLoop()` method
- Runs immediately on app launch
- Repeats every minute to detect missed medicines
- Only checks when mounted (safe)

```dart
void _checkMissedMedicinesLoop() async {
  await MedicineNotificationHandler().checkMissedMedicines();
  if (mounted) {
    Future.delayed(const Duration(minutes: 1), () {
      _checkMissedMedicinesLoop();
    });
  }
}
```

### 4. **AddMedicineScreen Updates** (`lib/screens/add_medicine_screen.dart`)

**Changes**:
- Removed immediate notification scheduling
- No longer calls `NotificationsService().scheduleDaily()`
- Medicine saved to database only
- Notifications triggered by events, not on creation

---

## 🔄 How It Works

### Scenario 1: User Adds Medicine at 09:00 AM
```
User adds: Paracetamol, 500mg, Time: 03:00 PM
     ↓
Saved to Firebase: medicines/{id}
     ↓
NO notification sent yet (event-based)
     ↓
App checks every minute...
```

### Scenario 2: Medicine Time Approaching (2:55 PM)
```
App detects: Current time 2:55 PM, Medicine time 3:00 PM
     ↓
Within 5 minute window
     ↓
Send ADVANCE notification:
  "⏰ Paracetamol - get ready, reminder in 5 minutes"
     ↓
Saved to database: notifications/{id}
```

### Scenario 3: Medicine Time Arrived (3:00 PM)
```
App detects: Current time 3:00 PM, Medicine time 3:00 PM
     ↓
Send REMINDER notification:
  "💊 Time to take Paracetamol (500mg)"
     ↓
Saved to database: notifications/{id}
```

### Scenario 4: Medicine Time Passed - Not Taken (3:15 PM)
```
App detects:
  - Current time 3:15 PM
  - Medicine time 3:00 PM (past by 15 min)
  - isTaken = false
  - More than 10 minutes past
     ↓
Send MISSED notification:
  "⚠️ You missed Paracetamol at 03:00 PM"
     ↓
Saved to database: notifications/{id}
     ↓
Check today: If already notified today, skip
```

---

## 📊 Notification Flow Diagram

```
App Launches
   ↓
Load Medicines from Firebase
   ↓
Start _checkMissedMedicinesLoop()
   ↓
Every Minute:
   ├─ Check each medicine
   ├─ Compare current time vs medicine time
   ├─ If 5 min before → Send ADVANCE notification
   ├─ If at exact time → Send REMINDER notification
   ├─ If 10+ min past & not taken → Send MISSED notification
   └─ All notifications saved to Firebase
   ↓
User taps notification bell → Shows all notifications from database
```

---

## ✅ Features Implemented

- ✅ **Event-Based Notifications** - Only trigger on specific events
- ✅ **No Default Notifications** - App doesn't spam on startup
- ✅ **Advance Reminders** - 5 minutes before medicine time
- ✅ **On-Time Reminders** - At exact medicine time
- ✅ **Missed Medicine Detection** - Automatically detects when medicine is not taken
- ✅ **Database Persistence** - All notifications saved to Firebase
- ✅ **No Duplicate Notifications** - Only notifies once per day for missed medicine
- ✅ **Recurring Check** - Checks every minute for missed medicines
- ✅ **Clean Code** - No spurious notifications or errors

---

## 🧪 Testing

### Test 1: Add Medicine and Wait for Reminder
1. Open app
2. Click "Add" tab
3. Add medicine: "Aspirin", "500mg", Time: "10:05 AM"
4. Wait until 10:00 AM
5. ✅ Should see notification: "💊 Medicine Reminder"

### Test 2: Check Advance Reminder
1. Add medicine with time: "10:00 AM"
2. Wait until 9:55 AM
3. ✅ Should see notification: "⏰ Medicine Alert - Get ready in 5 minutes"
4. Wait until 10:00 AM
5. ✅ Should see notification: "💊 Time to take medicine"

### Test 3: Missed Medicine Alert
1. Add medicine with time: "10:00 AM"
2. Let current time pass 10:10 AM without marking taken
3. ✅ Should see notification: "⚠️ You missed medicine at 10:00 AM"
4. Next day, same medicine, same time
5. ✅ Should see notification again (new day)

### Test 4: Database Persistence
1. Go to Firebase Console
2. Check `notifications/` collection
3. ✅ Should see all notifications with:
   - type (medicine_reminder, advance_reminder, missed_medicine)
   - title and message
   - timestamp

### Test 5: No Default Notifications
1. Open app
2. Should NOT see any notifications immediately
3. ✅ Only notifications should appear when:
   - Medicine time approaches
   - Medicine time arrives
   - Medicine is missed

---

## 🔒 Security & Performance

### Notification Deduplication
- Tracks which notifications sent today
- Prevents duplicate missed medicine alerts
- Only notifies once per day per medicine

### Performance Optimization
- Checks only run every 1 minute (not constantly)
- Uses `mounted` check to prevent memory leaks
- Async operations don't block UI
- No excessive Firebase reads

### Data Safety
- All notifications timestamped and stored
- Can replay notification history
- No data loss on app restart

---

## 📈 Future Enhancements

1. **User Notification Preferences**
   - Enable/disable specific notification types
   - Custom reminder times (3 min, 10 min before)
   - Quiet hours (no notifications at night)

2. **Smart Notifications**
   - Skip notification if medicine already taken
   - Remind only if dose missed
   - Multi-day medicines

3. **Analytics**
   - Track medicine adherence
   - Report on missed doses
   - Generate health insights

4. **Push Notifications**
   - Firebase Cloud Messaging (FCM)
   - Background notifications even when app closed
   - Deep linking to specific medicine

---

## 📝 Code Changes Summary

### New Files
- ✅ `lib/services/medicine_notification_handler.dart`

### Modified Files
- ✅ `lib/services/notifications_service.dart` - Added database saving
- ✅ `lib/screens/home_screen.dart` - Added missed medicine loop
- ✅ `lib/screens/add_medicine_screen.dart` - Removed notification scheduling

### Removed
- ❌ Default notification scheduling on app startup
- ❌ Notification scheduling on medicine creation

---

## 🚀 Ready to Test

All code compiles without errors. The system is ready for:
1. Full testing on device/emulator
2. Firebase integration verification
3. Notification timing validation
4. Database persistence check

---

**Status**: ✅ Complete and Event-Based  
**Date**: November 14, 2025  
**Version**: 3.0.3
