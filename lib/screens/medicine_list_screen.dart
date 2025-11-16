import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../firebase_operations.dart';
import '../models/medicine_history.dart';
import 'add_medicine_screen.dart';
import 'dart:async';

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
  final List<_DoseEntry> _todayDoseEntries = [];
  Map<String, List<MedicineHistory>> _todayHistory = {};
  final List<Timer> _doseTimers = [];

  @override
  void initState() {
    super.initState();
    _buildDoseEntries();
    _loadTodayHistory();
  }

  @override
  void didUpdateWidget(MedicineListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild dose entries when medicines list changes
    if (oldWidget.medicines != widget.medicines) {
      _buildDoseEntries();
    }
  }

  void _buildDoseEntries() {
    _todayDoseEntries.clear();

    // In the Medicines tab, show ALL medicines regardless of the day
    // The filtering by day is only for the Dashboard
    for (int medIdx = 0; medIdx < widget.medicines.length; medIdx++) {
      final med = widget.medicines[medIdx];

      final times = med.times.isNotEmpty ? med.times : [med.time];
      final baseId = med.id.hashCode & 0x7fffffff;
      for (int i = 0; i < times.length; i++) {
        final t = times[i];
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
    if (mounted) setState(() {});
    _scheduleDoseTimers();
  }

  DateTime? _parseTimeStringToToday(String timeStr) {
    try {
      final parts = timeStr.split(' ');
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
      _scheduleDoseTimers();
    } catch (e) {
      debugPrint('Error loading today history: $e');
    }
  }

  void _clearDoseTimers() {
    for (final t in _doseTimers) {
      try {
        t.cancel();
      } catch (_) {}
    }
    _doseTimers.clear();
  }

  Future<void> _scheduleDoseTimers() async {
    _clearDoseTimers();
    final now = DateTime.now();
    for (final entry in _todayDoseEntries) {
      final dt = entry.scheduledDateTime;
      final tStart = dt;
      final tEnd = dt.add(const Duration(minutes: 10));
      // removed alert-specific timers
      // If dose already taken or missed, skip
      final todays = _todayHistory[entry.medicine.id] ?? [];
      final takenForDose = todays
          .where((h) => h.status == 'taken' && h.doseIndex == entry.doseIndex)
          .length;
      final missedForDose = todays
          .where((h) => h.status == 'missed' && h.doseIndex == entry.doseIndex)
          .length;
      if ((takenForDose + missedForDose) > 0) continue;

      if (now.isBefore(tStart)) {
        // schedule at tStart to refresh UI (show Take button)
        final dur = tStart.difference(now);
        _doseTimers.add(
          Timer(dur, () {
            if (mounted) setState(() {});
          }),
        );
        // 1-minute-before alert handled by OS-scheduled notifications
        // schedule missed at tEnd
        final dur2 = tEnd.difference(now);
        if (dur2.isNegative == false) {
          // in-window reminders handled by OS-scheduled notifications
          _doseTimers.add(
            Timer(dur2, () async {
              // If still not taken, mark missed
              final todays2 = _todayHistory[entry.medicine.id] ?? [];
              final takenNow = todays2
                  .where(
                    (h) =>
                        h.status == 'taken' && h.doseIndex == entry.doseIndex,
                  )
                  .length;
              final missedNow = todays2
                  .where(
                    (h) =>
                        h.status == 'missed' && h.doseIndex == entry.doseIndex,
                  )
                  .length;
              if ((takenNow + missedNow) == 0) {
                await _markDoseMissedAuto(entry);
              }
              if (mounted) setState(() {});
            }),
          );
        }
      } else if (now.isAtSameMomentAs(tStart) ||
          (now.isAfter(tStart) && now.isBefore(tEnd))) {
        // We're in the window, schedule missed at tEnd and remaining snackbars
        final dur2 = tEnd.difference(now);
        if (dur2.isNegative == false) {
          _doseTimers.add(
            Timer(dur2, () async {
              final todays2 = _todayHistory[entry.medicine.id] ?? [];
              final takenNow = todays2
                  .where(
                    (h) =>
                        h.status == 'taken' && h.doseIndex == entry.doseIndex,
                  )
                  .length;
              final missedNow = todays2
                  .where(
                    (h) =>
                        h.status == 'missed' && h.doseIndex == entry.doseIndex,
                  )
                  .length;
              if ((takenNow + missedNow) == 0) {
                await _markDoseMissedAuto(entry);
              }
              if (mounted) setState(() {});
            }),
          );
        }
      }
      // Don't auto-mark immediately for past doses - only via timers
    }
  }

  Future<void> _markDoseMissedAuto(_DoseEntry entry) async {
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
      await _loadTodayHistory();
      _scheduleDoseTimers();
    } catch (e) {
      debugPrint('Error auto-marking dose missed: $e');
    }
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
      await _loadTodayHistory();
      _scheduleDoseTimers();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error marking dose taken: $e');
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
      await _loadTodayHistory();
      _scheduleDoseTimers();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error marking dose missed: $e');
    }
  }

  String _formatTimeOfDay(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }

  void _openAddMedicineScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddMedicineScreen(
          onMedicineAdded: (medicine) async {
            try {
              final medicineMap = medicine.toMap();
              await FirebaseOperations.writeData(
                'medicines/${medicine.id}',
                medicineMap,
              );
              debugPrint('✓ Medicine added: ${medicine.name}');
              if (!context.mounted) return;
              // Show snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${medicine.name} added successfully'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
              // Wait for snackbar and Firebase sync
              await Future.delayed(const Duration(milliseconds: 500));
              if (!context.mounted) return;
              Navigator.of(context).pop();
              // Rebuild dose entries when returning
              _buildDoseEntries();
            } catch (e) {
              debugPrint('Error adding medicine: $e');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error adding medicine: $e')),
              );
            }
          },
        ),
      ),
    );
  }

  void _openEditMedicineScreen(Medicine medicine) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddMedicineScreen(
          medicineToEdit: medicine,
          onMedicineAdded: (updatedMedicine) async {
            try {
              final medicineMap = updatedMedicine.toMap();
              await FirebaseOperations.writeData(
                'medicines/${updatedMedicine.id}',
                medicineMap,
              );
              debugPrint('✓ Medicine updated: ${updatedMedicine.name}');
              if (!context.mounted) return;
              // Show snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${updatedMedicine.name} updated successfully'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
              // Wait for snackbar and Firebase sync
              await Future.delayed(const Duration(milliseconds: 500));
              if (!context.mounted) return;
              Navigator.of(context).pop();
              // Rebuild dose entries when returning
              _buildDoseEntries();
            } catch (e) {
              debugPrint('Error updating medicine: $e');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating medicine: $e')),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.medicines.isEmpty
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
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: List.generate(_todayDoseEntries.length, (index) {
                    final entry = _todayDoseEntries[index];
                    final medicine = entry.medicine;
                    final now = DateTime.now();
                    final T = entry.scheduledDateTime;
                    final windowEnd = T.add(const Duration(minutes: 10));

                    final todays = _todayHistory[medicine.id] ?? [];
                    final isTaken = todays
                        .where(
                          (h) =>
                              h.status == 'taken' &&
                              h.doseIndex == entry.doseIndex,
                        )
                        .isNotEmpty;
                    final isMissed = todays
                        .where(
                          (h) =>
                              h.status == 'missed' &&
                              h.doseIndex == entry.doseIndex,
                        )
                        .isNotEmpty;
                    final showTakeButton =
                        !isTaken &&
                        !isMissed &&
                        (now.isAtSameMomentAs(T) ||
                            (now.isAfter(T) && now.isBefore(windowEnd)));
                    final showToBeTaken =
                        !isTaken && !isMissed && now.isBefore(T);
                    final showMissed =
                        !isTaken && (isMissed || now.isAfter(windowEnd));

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Colors.blue.shade50.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.blue.shade200,
                                        Colors.blue.shade400,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.medication_liquid,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        medicine.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            'Dosage: ${medicine.dosage}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _formatTimeOfDay(T),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade600,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Weekly days display
                                      Text(
                                        'Days: ${medicine.weeklyDays.map((d) => d.substring(0, 3)).join(", ")}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Status indicators and Take button
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (showToBeTaken)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'To Be Taken',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    if (showTakeButton)
                                      SizedBox(
                                        width: 70,
                                        height: 36,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            elevation: 3,
                                          ),
                                          onPressed: () async {
                                            await _markDoseTaken(entry);
                                          },
                                          child: const Text(
                                            'Take',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    if (isTaken)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'Taken',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    if (showMissed)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'Missed',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'missed') {
                                          _markDoseMissed(entry);
                                        } else if (value == 'edit') {
                                          _openEditMedicineScreen(medicine);
                                        } else if (value == 'delete') {
                                          _showDeleteDialog(context, medicine);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => [
                                        if (!isTaken && !showMissed)
                                          const PopupMenuItem(
                                            value: 'missed',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.close,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Mark Missed'),
                                              ],
                                            ),
                                          ),
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Edit Medicine'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Delete Medicine'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      child: Icon(
                                        Icons.more_vert,
                                        color: Colors.grey.shade600,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddMedicineScreen,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
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
              Navigator.pop(context);
              // Call delete callback
              widget.onDelete(medicine.id);
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${medicine.name} deleted'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
              // Wait and rebuild
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _buildDoseEntries();
                }
              });
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _clearDoseTimers();
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
