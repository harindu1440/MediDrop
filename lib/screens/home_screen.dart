import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../firebase_operations.dart';
import '../models/medicine.dart';
import '../models/medicine_history.dart';
import 'medicine_list_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'liquids_screen.dart';
import '../widgets/liquid_bottle.dart';
import '../services/liquid_level_service.dart';
import '../models/liquid_level.dart';

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

  Map<String, List<MedicineHistory>> _todayHistory = {};
  List<_DoseEntry> _todayDoseEntries = [];
  final List<Timer> _doseTimers = [];
  StreamSubscription<DatabaseEvent>? _medicinesSubscription;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
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
      debugPrint('Error setting up medicines listener: $e');
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
      // Reschedule dose timers when history changes
      _scheduleDoseTimers();
    } catch (e) {
      debugPrint('Error loading today history: $e');
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

          // Get today's day name
          final now = DateTime.now();
          final daysOfWeek = [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ];
          final todayDayName = daysOfWeek[now.weekday - 1];

          for (final med in medicines) {
            // Check if this medicine should be taken today
            if (med.weeklyDays.isEmpty ||
                !med.weeklyDays.contains(todayDayName)) {
              continue;
            }

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
        // Load today's history first so we don't re-schedule reminders for doses already handled
        await _loadTodayHistory();
        // Sort doses by closeness to now
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
        // Reschedule timers for doses
        _scheduleDoseTimers();
      } else {
        setState(() {
          medicines = [];
          _isLoading = false;
          _todayDoses = 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading medicines: $e');
      setState(() => _isLoading = false);
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

  void _scheduleDoseTimers() {
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
        // 1-minute-before alert handled via OS-scheduled notification (see scheduling step)
        // schedule missed at tEnd
        final dur2 = tEnd.difference(now);
        if (dur2.isNegative == false) {
          // in-window alerts are scheduled via OS-level notifications
          // in-window reminders handled via OS-scheduled notifications (see scheduling step)
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
                await _markDoseMissed(entry);
              }
              if (mounted) setState(() {});
            }),
          );
        }
      } else if (now.isAtSameMomentAs(tStart) ||
          (now.isAfter(tStart) && now.isBefore(tEnd))) {
        // We're in the active window; schedule missed at tEnd and remaining snackbars
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
                await _markDoseMissed(entry);
              }
              if (mounted) setState(() {});
            }),
          );
        }
      }
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
      await _loadTodayHistory();
      // Refresh timers/state after taking dose
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

  void _deleteMedicine(String medicineId) async {
    try {
      // Remove node from database
      await FirebaseOperations.deleteData('medicines/$medicineId');
      debugPrint('✓ Medicine deleted: $medicineId');

      // Force reload medicines after delete
      await _loadMedicines();

      // Notification cleanup removed

      // Refresh dashboard immediately
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error deleting medicine: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting medicine: $e')));
      }
    }
  }

  Future<void> _recordWash() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final data = {
      'id': id,
      'type': 'wash',
      'timestamp': DateTime.now().toIso8601String(),
    };
    try {
      await FirebaseOperations.writeData('wash_events/$id', data);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Wash recorded')));
      }
    } catch (e) {
      debugPrint('Error recording wash: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error recording wash: $e')));
      }
    }
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
            // Header Card + Liquid Level (side by side)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome box (expanded)
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                              Colors.blue.shade800,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: const [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.1),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Welcome to MediDrop',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Smart Liquid Dosage System',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withValues(
                                            alpha: 0.95,
                                          ),
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.local_drink_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '✓ All medicines on track',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Decorative circles
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -20,
                        bottom: -20,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Liquid level widget + info (compact)
                FutureBuilder<LiquidLevel>(
                  future: LiquidLevelService.getDefaultBottle(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final b = snap.data!;
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          LiquidBottleWidget(
                            capacity: b.capacity,
                            currentLevel: b.currentLevel,
                            width: 56,
                            height: 120,
                            showPercentage: true,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${b.currentLevel.toStringAsFixed(0)} ml',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '/ ${b.capacity.toStringAsFixed(0)} ml',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),
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
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Wash Nozzel Card
            Card(
              margin: const EdgeInsets.only(bottom: 18),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                          colors: [Colors.blue.shade200, Colors.blue.shade400],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.cleaning_services,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Wash Nozzel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Press to wash the nozzel',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          elevation: 3,
                        ),
                        onPressed: () async {
                          await _recordWash();
                        },
                        child: const Text('Wash Nozzel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Upcoming Medicines
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Today\'s Medicines',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
                      final now = DateTime.now();
                      final T = entry.scheduledDateTime;
                      final windowEnd = T.add(const Duration(minutes: 10));
                      final todays = _todayHistory[entry.medicine.id] ?? [];
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
                          isMissed || (!isTaken && now.isAfter(windowEnd));
                      final medicine = entry.medicine;
                      // final freqCount = _frequencyCount(medicine.frequency);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
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
                                  child: Icon(
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
                                            _formatTimeOfDay(
                                              entry.scheduledDateTime,
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade600,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // New status logic per requirements
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
                                  ],
                                ),
                              ],
                            ),
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
      const LiquidsScreen(),
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
        automaticallyImplyLeading: false,
        actions: const [],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Medicines',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.opacity), label: 'Liquids'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }

  @override
  void dispose() {
    _medicinesSubscription?.cancel();
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
