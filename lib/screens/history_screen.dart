import 'package:flutter/material.dart';
import '../firebase_operations.dart';
import '../models/medicine_history.dart';
import '../services/notifications_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MedicineHistory> history = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, taken, missed, skipped

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await FirebaseOperations.readData('medicine_history');
      if (data != null && data is Map) {
        setState(() {
          history = data.entries
              .map(
                (e) =>
                    MedicineHistory.fromMap(Map<String, dynamic>.from(e.value)),
              )
              .toList();
          // Sort by date descending (newest first)
          history.sort((a, b) => b.dateTaken.compareTo(a.dateTaken));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading history: $e');
      setState(() => _isLoading = false);
    }
  }

  List<MedicineHistory> _getFilteredHistory() {
    if (_selectedFilter == 'all') {
      return history;
    } else {
      return history.where((item) => item.status == _selectedFilter).toList();
    }
  }

  void _markMedicineTaken(
    String medicineId,
    String medicineName,
    String dosage, {
    int? doseIndex,
  }) async {
    final historyId = DateTime.now().millisecondsSinceEpoch.toString();
    final medicineHistory = MedicineHistory(
      id: historyId,
      medicineId: medicineId,
      medicineName: medicineName,
      dosage: dosage,
      dateTaken: DateTime.now(),
      status: 'taken',
      doseIndex: doseIndex,
    );

    try {
      await FirebaseOperations.writeData(
        'medicine_history/$historyId',
        medicineHistory.toMap(),
      );
      print('✓ Marked as taken: $medicineName');
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $medicineName marked as taken!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error marking medicine as taken: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
            if (name == medicineName &&
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
  }

  void _markMedicineMissed(
    String medicineId,
    String medicineName,
    String dosage, {
    int? doseIndex,
  }) async {
    final historyId = DateTime.now().millisecondsSinceEpoch.toString();
    final medicineHistory = MedicineHistory(
      id: historyId,
      medicineId: medicineId,
      medicineName: medicineName,
      dosage: dosage,
      dateTaken: DateTime.now(),
      status: 'missed',
      doseIndex: doseIndex,
    );

    try {
      await FirebaseOperations.writeData(
        'medicine_history/$historyId',
        medicineHistory.toMap(),
      );
      print('✓ Marked as missed: $medicineName');
      _loadHistory();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ $medicineName marked as missed'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error marking medicine as missed: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'taken':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'skipped':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusIcon(String status) {
    switch (status) {
      case 'taken':
        return '✓';
      case 'missed':
        return '✗';
      case 'skipped':
        return '⊘';
      default:
        return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredHistory = _getFilteredHistory();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine History'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildFilterChip('all', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('taken', 'Taken', Colors.green),
                const SizedBox(width: 8),
                _buildFilterChip('missed', 'Missed', Colors.red),
                const SizedBox(width: 8),
                _buildFilterChip('skipped', 'Skipped', Colors.orange),
              ],
            ),
          ),
          // History List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No history yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredHistory.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      final item = filteredHistory[index];
                      return _buildHistoryCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, [Color? color]) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: color ?? Theme.of(context).colorScheme.primary,
      backgroundColor: Colors.grey.shade200,
      labelStyle: TextStyle(
        color: _selectedFilter == value ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildHistoryCard(MedicineHistory item) {
    final statusColor = _getStatusColor(item.status);
    final statusIcon = _getStatusIcon(item.status);
    final formattedDate = _formatDateTime(item.dateTaken);
    final doseInfo = item.doseIndex != null
        ? ' (Dose ${item.doseIndex! + 1})'
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              statusIcon,
              style: TextStyle(
                fontSize: 24,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          '${item.medicineName}$doseInfo',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Dosage: ${item.dosage}'),
            Text(formattedDate),
            if (item.notes != null) ...[
              const SizedBox(height: 4),
              Text(
                'Notes: ${item.notes}',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            if (item.status != 'taken')
              PopupMenuItem(
                child: const Text('Mark as Taken'),
                onTap: () {
                  _markMedicineTaken(
                    item.medicineId,
                    item.medicineName,
                    item.dosage,
                  );
                },
              ),
            if (item.status != 'missed')
              PopupMenuItem(
                child: const Text('Mark as Missed'),
                onTap: () {
                  _markMedicineMissed(
                    item.medicineId,
                    item.medicineName,
                    item.dosage,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final itemDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (itemDate == today) {
      dateStr = 'Today';
    } else if (itemDate == yesterday) {
      dateStr = 'Yesterday';
    } else {
      dateStr =
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }

    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    return '$dateStr at $timeStr';
  }
}
