import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../firebase_operations.dart';
import '../models/medicine_history.dart';
import '../services/notifications_service.dart';

/// Helper: extract numeric frequency from strings like "2 times" or "2/day"
int _frequencyCount(String freq) {
  try {
    final match = RegExp(r"(\d+)").firstMatch(freq);
    if (match != null) return int.parse(match.group(0)!);
  } catch (_) {}
  return 1;
}

class MedicineListScreen extends StatefulWidget {
  final List<Medicine> medicines;
  final Function(String) onDelete;

  const MedicineListScreen({
    super.key,
    required this.medicines,
    required this.onDelete,
  });

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  Map<String, List<MedicineHistory>> _todayHistory = {};

  @override
  void initState() {
    super.initState();
    _loadTodayHistory();
  }

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

  @override
  Widget build(BuildContext context) {
    return widget.medicines.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.medication_liquid,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Medicines Found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first medicine to get started',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: widget.medicines.length,
            itemBuilder: (context, index) {
              final medicine = widget.medicines[index];

              final todays = _todayHistory[medicine.id] ?? [];
              final takenCount = todays
                  .where((h) => h.status == 'taken')
                  .length;
              final missedCount = todays
                  .where((h) => h.status == 'missed')
                  .length;
              final freq = _frequencyCount(medicine.frequency);
              final allowActions = (takenCount + missedCount) < freq;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.medication_liquid,
                          color: Colors.blue,
                          size: 32,
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
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  medicine.time,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.repeat,
                                  size: 12,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  medicine.frequency,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Actions column: Taken / Missed text buttons and badges
                      Column(
                        children: [
                          if (allowActions)
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await _markAsTaken(medicine);
                                    await _loadTodayHistory();
                                  },
                                  child: const Text(
                                    'Taken',
                                    style: TextStyle(color: Colors.green),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TextButton(
                                  onPressed: () async {
                                    await _markAsMissed(medicine);
                                    await _loadTodayHistory();
                                  },
                                  child: const Text(
                                    'Missed',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 4),
                          if (takenCount > 0)
                            Chip(
                              label: Text(
                                'Taken${takenCount > 1 ? ' x$takenCount' : ''}',
                              ),
                              backgroundColor: Colors.green.shade100,
                              labelStyle: const TextStyle(color: Colors.green),
                            ),
                          if (missedCount > 0)
                            Chip(
                              label: Text(
                                'Missed${missedCount > 1 ? ' x$missedCount' : ''}',
                              ),
                              backgroundColor: Colors.red.shade100,
                              labelStyle: const TextStyle(color: Colors.red),
                            ),

                          // Delete popup remains for full actions
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                _showDeleteDialog(context, medicine);
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  void _showDeleteDialog(BuildContext context, Medicine medicine) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text('Delete "${medicine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onDelete(medicine.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${medicine.name} deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsTaken(Medicine medicine) async {
    final historyId = DateTime.now().millisecondsSinceEpoch.toString();
    final medicineHistory = MedicineHistory(
      id: historyId,
      medicineId: medicine.id,
      medicineName: medicine.name,
      dosage: medicine.dosage,
      dateTaken: DateTime.now(),
      status: 'taken',
    );

    try {
      await FirebaseOperations.writeData(
        'medicine_history/$historyId',
        medicineHistory.toMap(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ${medicine.name} marked as taken!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }

    // Cancel any scheduled or saved notifications for this medicine
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
            if (name == medicine.name &&
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
      print('Error checking notifications to cancel: $e');
    }

    // Refresh today's history and UI
    await _loadTodayHistory();
  }

  Future<void> _markAsMissed(Medicine medicine) async {
    final historyId = DateTime.now().millisecondsSinceEpoch.toString();
    final medicineHistory = MedicineHistory(
      id: historyId,
      medicineId: medicine.id,
      medicineName: medicine.name,
      dosage: medicine.dosage,
      dateTaken: DateTime.now(),
      status: 'missed',
    );

    try {
      await FirebaseOperations.writeData(
        'medicine_history/$historyId',
        medicineHistory.toMap(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${medicine.name} marked as missed'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error marking as missed: $e');
    }

    // Refresh today's history and UI
    await _loadTodayHistory();
  }
}
