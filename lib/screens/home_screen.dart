import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../firebase_operations.dart';
import '../models/medicine.dart';
import '../models/medicine_history.dart';
import '../services/medicine_notification_handler.dart';
import '../services/notifications_service.dart';
import 'add_medicine_screen.dart';
import 'medicine_list_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Medicine> medicines = [];
  int _todayDoses = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  int _notificationCount = 0;
  Map<String, List<MedicineHistory>> _todayHistory = {};
  List<_DoseEntry> _todayDoseEntries = [];
  StreamSubscription<DatabaseEvent>? _medicinesSubscription;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    _checkMissedMedicinesLoop();
    _setupMedicinesListener();
  }

  /// Set up real-time listener for medicines changes using Firebase onValue
  void _setupMedicinesListener() {
    try {
      final ref = FirebaseDatabase.instance.ref('medicines');
      _medicinesSubscription = ref.onValue.listen((event) async {
        // On any change, reload medicines and reschedule reminders if needed
        await _loadMedicines();
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error setting up medicines listener: $e');
    }
  }

  void _checkMissedMedicinesLoop() async {
    await MedicineNotificationHandler().checkMissedMedicines();
    // Refresh notification list after checks
    await _loadNotifications();

    if (mounted) {
      Future.delayed(const Duration(minutes: 1), () {
        _checkMissedMedicinesLoop();
      });
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await FirebaseOperations.readData('notifications');
      final List<Map<String, dynamic>> items = [];
      if (data != null && data is Map) {
        data.forEach((key, value) {
          try {
            final m = Map<String, dynamic>.from(value);
            m['id'] = key;
            items.add(m);
          } catch (_) {}
        });
      }

      // sort by timestamp desc if available
      items.sort((a, b) {
        final ta =
            DateTime.tryParse(a['timestamp'] ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb =
            DateTime.tryParse(b['timestamp'] ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });

      setState(() {
        _notifications = items;
        _notificationCount = items.length;
      });
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  /// Load today's medicine history grouped by medicineId
  Future<void> _loadTodayHistory() async {
    try {
      final data = await FirebaseOperations.readData('medicine_history');
      final Map<String, List<MedicineHistory>> grouped = {};
      if (data != null && data is Map) {
        for (var entry in data.entries) {
          try {
            final m = MedicineHistory.fromMap(
              Map<String, dynamic>.from(entry.value),
            );
            final dt = m.dateTaken;
            final now = DateTime.now();
            if (dt.year == now.year &&
                dt.month == now.month &&
                dt.day == now.day) {
              grouped.putIfAbsent(m.medicineId, () => []).add(m);
            }
          } catch (_) {}
        }
      }
      setState(() {
        _todayHistory = grouped;
      });
    } catch (e) {
      print('Error loading today history: $e');
    }
  }

  Future<void> _loadMedicines() async {
    try {
      final data = await FirebaseOperations.readData('medicines');
      if (data != null && data is Map) {
        setState(() {
          medicines = data.entries
              .map((e) => Medicine.fromMap(Map<String, dynamic>.from(e.value)))
              .toList();
          _isLoading = false;
          // build per-dose entries for today
          _todayDoseEntries = [];
          for (final med in medicines) {
            final baseId = med.id.hashCode & 0x7fffffff;
            for (var i = 0; i < med.times.length; i++) {
              final t = med.times[i];
              final dt = _parseTimeStringToToday(t);
              if (dt != null) {
                _todayDoseEntries.add(
                  _DoseEntry(
                    medicine: med,
                    scheduledDateTime: dt,
                    doseIndex: i,
                    notificationId: baseId + i + 100,
                  ),
                );
              }
            }
          }
          _todayDoses = _todayDoseEntries.length;
        });
        // Ensure scheduled notifications exist for each scheduled dose (cancel/reschedule to avoid duplicates)
        for (final entry in _todayDoseEntries) {
          try {
            await NotificationsService().cancelNotification(
              entry.notificationId,
            );
            await NotificationsService().scheduleDaily(
              entry.notificationId,
              entry.medicine.name,
              entry.medicine.dosage,
              _formatTimeOfDay(entry.scheduledDateTime),
            );
          } catch (e) {
            print(
              'Error scheduling reminder for ${entry.medicine.name} dose ${entry.doseIndex}: $e',
            );
          }
        }
        // Load today's history to show taken/missed states and sort doses by closeness to now
        await _loadTodayHistory();
        _todayDoseEntries.sort((a, b) {
          final aDist = a.scheduledDateTime
              .difference(DateTime.now())
              .inMinutes
              .abs();
          final bDist = b.scheduledDateTime
              .difference(DateTime.now())
              .inMinutes
              .abs();
          return aDist.compareTo(bDist);
        });
      } else {
        setState(() {
          medicines = [];
          _isLoading = false;
          _todayDoses = 0;
        });
      }
    } catch (e) {
      print('Error loading medicines: $e');
      setState(() => _isLoading = false);
    }
  }

  DateTime? _parseTimeStringToToday(String timeString) {
    try {
      final parts = timeString.split(' ');
      if (parts.length != 2) return null;
      final hm = parts[0].split(':');
      int hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);
      final period = parts[1];
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  String _formatTimeOfDay(DateTime dt) {
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }

  Future<void> _markDoseTaken(_DoseEntry entry) async {
    final medicine = entry.medicine;
    final historyId = DateTime.now().millisecondsSinceEpoch.toString();
    final entryObj = MedicineHistory(
      id: historyId,
      medicineId: medicine.id,
      medicineName: medicine.name,
      dosage: medicine.dosage,
      dateTaken: DateTime.now(),
      status: 'taken',
      doseIndex: entry.doseIndex,
    );
    try {
      await FirebaseOperations.writeData(
        'medicine_history/$historyId',
        entryObj.toMap(),
      );
      // cancel scheduled notifications for this dose (main and advance)
      try {
        await NotificationsService().cancelNotification(entry.notificationId);
        await NotificationsService().cancelNotification(
          entry.notificationId + 10000,
        );
      } catch (e) {
        print('Error cancelling notifications for taken dose: $e');
      }
      // remove corresponding DB notification entries by localId
      await _cleanupNotificationDbEntries(entry.notificationId);
      await _cleanupNotificationDbEntries(entry.notificationId + 10000);
      await _loadTodayHistory();
      // Refresh notifications in real-time
      await _loadNotifications();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error marking dose taken: $e');
    }
  }

  Future<void> _markDoseMissed(_DoseEntry entry) async {
    final medicine = entry.medicine;
    final historyId = DateTime.now().millisecondsSinceEpoch.toString();
    final entryObj = MedicineHistory(
      id: historyId,
      medicineId: medicine.id,
      medicineName: medicine.name,
      dosage: medicine.dosage,
      dateTaken: DateTime.now(),
      status: 'missed',
      doseIndex: entry.doseIndex,
    );
    try {
      await FirebaseOperations.writeData(
        'medicine_history/$historyId',
        entryObj.toMap(),
      );
      // cancel scheduled notifications for this dose as it's been handled
      try {
        await NotificationsService().cancelNotification(entry.notificationId);
        await NotificationsService().cancelNotification(
          entry.notificationId + 10000,
        );
      } catch (e) {
        print('Error cancelling notifications for missed dose: $e');
      }
      // remove corresponding DB notification entries by localId
      await _cleanupNotificationDbEntries(entry.notificationId);
      await _cleanupNotificationDbEntries(entry.notificationId + 10000);
      await _loadTodayHistory();
      // Refresh notifications in real-time
      await _loadNotifications();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error marking dose missed: $e');
    }
  }

  Future<void> _cleanupNotificationDbEntries(int localId) async {
    try {
      final notificationsDb = await FirebaseOperations.readData(
        'notifications',
      );
      if (notificationsDb != null && notificationsDb is Map) {
        for (var entry in notificationsDb.entries) {
          final key = entry.key;
          final value = entry.value;
          if (value is Map && value['localId'] == localId) {
            await FirebaseOperations.deleteData('notifications/$key');
            print('✓ Deleted notification DB entry for localId: $localId');
          }
        }
      }
    } catch (e) {
      print('Error cleaning up notification DB entries: $e');
    }
  }

  void _addMedicine(Medicine medicine) async {
    try {
      final medicineMap = medicine.toMap();
      await FirebaseOperations.writeData(
        'medicines/${medicine.id}',
        medicineMap,
      );
      print('✓ Medicine added: ${medicine.name}');

      // Schedule notifications for each dose time for this medicine
      final int baseId = medicine.id.hashCode & 0x7fffffff;
      for (var i = 0; i < (medicine.times.length); i++) {
        final tid = baseId + i + 100;
        final timeStr = medicine.times[i];
        try {
          await NotificationsService().cancelNotification(tid);
        } catch (_) {}
        await NotificationsService().scheduleDaily(
          tid,
          medicine.name,
          medicine.dosage,
          timeStr,
        );
      }

      await _loadMedicines();
    } catch (e) {
      print('Error adding medicine: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding medicine: $e')));
      }
    }
  }

  void _deleteMedicine(String medicineId) async {
    try {
      // Capture medicine name (if available) before delete to cleanup notifications
      final med = medicines.firstWhere(
        (m) => m.id == medicineId,
        orElse: () => Medicine(
          id: medicineId,
          name: '',
          dosage: '',
          time: '',
          frequency: '',
          dateAdded: DateTime.now(),
        ),
      );

      // Remove node from database
      await FirebaseOperations.deleteData('medicines/$medicineId');
      print('✓ Medicine deleted: $medicineId');

      // Force reload medicines after delete
      await _loadMedicines();

      // Cancel any scheduled notifications saved for this medicine
      try {
        final notificationsDb = await FirebaseOperations.readData(
          'notifications',
        );
        if (notificationsDb != null && notificationsDb is Map) {
          for (var entry in notificationsDb.entries) {
            final key = entry.key;
            final value = entry.value;
            if (value is Map) {
              final name = value['medicineName'] ?? '';
              final type = value['type'] ?? '';
              if (name == med.name &&
                  (type == 'medicine_reminder' || type == 'advance_reminder')) {
                final localId = value['localId'] is num
                    ? (value['localId'] as num).toInt()
                    : null;
                try {
                  await NotificationsService().clearNotification(
                    key.toString(),
                    localId: localId,
                  );
                } catch (e) {
                  // ignore: avoid_print
                  print('Error clearing notification $key: $e');
                }
              }
            }
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('Error cleaning notifications after delete: $e');
      }

      // Refresh dashboard immediately
      if (mounted) setState(() {});
    } catch (e) {
      print('Error deleting medicine: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting medicine: $e')));
      }
    }
  }

  Future<void> _showNotifications() async {
    // Load the latest notifications then show
    await _loadNotifications();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: double.maxFinite,
          child: _notifications.isEmpty
              ? const Text('No notifications')
              : ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    return _buildNotificationItemFromMap(n);
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: _notifications.length,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItemFromMap(Map<String, dynamic> n) {
    final title = n['title'] ?? n['type'] ?? 'Notification';
    final message = n['message'] ?? '';
    final timestamp = n['timestamp'] ?? '';
    final dbId = n['id']?.toString();
    final localId = n['localId'] is num ? (n['localId'] as num).toInt() : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  timestamp,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (dbId != null) {
                try {
                  await NotificationsService().clearNotification(
                    dbId,
                    localId: localId,
                  );
                } catch (e) {
                  // ignore: avoid_print
                  print('Error clearing notification $dbId: $e');
                }
                await _loadNotifications();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to MediDrop',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Smart Liquid dosage System',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Medicines',
                    value: medicines.length.toString(),
                    icon: Icons.medication,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Today\'s Doses',
                    value: _todayDoses.toString(),
                    icon: Icons.schedule,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Upcoming Medicines
            const Text(
              'Today\'s Medicines',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            medicines.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.medication_liquid,
                          size: 50,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No medicines added yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _todayDoseEntries.take(3).length,
                    itemBuilder: (context, index) {
                      final entry = _todayDoseEntries[index];
                      final medicine = entry.medicine;
                      final todays = _todayHistory[medicine.id] ?? [];
                      // count taken/missed for this specific doseIndex
                      final takenForDose = todays
                          .where(
                            (h) =>
                                h.status == 'taken' &&
                                h.doseIndex == entry.doseIndex,
                          )
                          .length;
                      final missedForDose = todays
                          .where(
                            (h) =>
                                h.status == 'missed' &&
                                h.doseIndex == entry.doseIndex,
                          )
                          .length;
                      // final freqCount = _frequencyCount(medicine.frequency);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.medication_liquid,
                                  color: Colors.blue,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      medicine.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dosage: ${medicine.dosage}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Scheduled: ${_formatTimeOfDay(entry.scheduledDateTime)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  if ((takenForDose + missedForDose) < 1)
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              _markDoseTaken(entry),
                                          child: const Text(
                                            'Taken',
                                            style: TextStyle(
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        TextButton(
                                          onPressed: () =>
                                              _markDoseMissed(entry),
                                          child: const Text(
                                            'Missed',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (takenForDose > 0)
                                    Chip(
                                      label: Text('Taken'),
                                      backgroundColor: Colors.green.shade100,
                                      labelStyle: const TextStyle(
                                        color: Colors.green,
                                      ),
                                    ),
                                  if (missedForDose > 0)
                                    Chip(
                                      label: Text('Missed'),
                                      backgroundColor: Colors.red.shade100,
                                      labelStyle: const TextStyle(
                                        color: Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      MedicineListScreen(medicines: medicines, onDelete: _deleteMedicine),
      const AddMedicineScreen(),
      const HistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Medi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              TextSpan(
                text: 'Drop',
                style: TextStyle(
                  color: Colors.yellow.shade200,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: _showNotifications,
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Medicines'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Add'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          if (index == 2) {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (context) =>
                        AddMedicineScreen(onMedicineAdded: _addMedicine),
                  ),
                )
                .then((_) => _loadMedicines());
          } else {
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _medicinesSubscription?.cancel();
    super.dispose();
  }
}

class _DoseEntry {
  final Medicine medicine;
  final DateTime scheduledDateTime;
  final int doseIndex;
  final int notificationId;

  _DoseEntry({
    required this.medicine,
    required this.scheduledDateTime,
    required this.doseIndex,
    required this.notificationId,
  });
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
