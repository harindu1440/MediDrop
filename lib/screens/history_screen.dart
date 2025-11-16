import 'package:flutter/material.dart';
import '../firebase_operations.dart';
import '../models/medicine_history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MedicineHistory> history = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, taken, missed

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
      debugPrint('Error loading history: $e');
      setState(() => _isLoading = false);
    }
  }

  List<MedicineHistory> _getFilteredHistory() {
    // Group by medicine + date, keep only latest per day
    final Map<String, MedicineHistory> uniqueByDay = {};

    for (var item in history) {
      final dateKey =
          '${item.medicineName}_${item.dateTaken.year}-${item.dateTaken.month}-${item.dateTaken.day}';
      // Keep the most recent entry for each medicine per day
      if (!uniqueByDay.containsKey(dateKey) ||
          item.dateTaken.isAfter(uniqueByDay[dateKey]!.dateTaken)) {
        uniqueByDay[dateKey] = item;
      }
    }

    final deduplicatedHistory = uniqueByDay.values.toList();
    deduplicatedHistory.sort((a, b) => b.dateTaken.compareTo(a.dateTaken));

    if (_selectedFilter == 'all') {
      return deduplicatedHistory;
    } else {
      return deduplicatedHistory
          .where((item) => item.status == _selectedFilter)
          .toList();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'taken':
        return Colors.green;
      case 'missed':
        return Colors.red;
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
      default:
        return '?';
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History'),
        content: const Text(
          'Are you sure you want to delete all medicine history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Show loading message
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clearing history...'),
            duration: Duration(milliseconds: 500),
          ),
        );

        // Delete from Firebase with retry logic
        bool deleteSucceeded = false;
        int retries = 0;
        const maxRetries = 3;

        while (!deleteSucceeded && retries < maxRetries) {
          try {
            await FirebaseOperations.deleteData('medicine_history');
            deleteSucceeded = true;
            debugPrint(
              '✓ History deleted successfully (attempt ${retries + 1})',
            );
          } catch (e) {
            retries++;
            if (retries < maxRetries) {
              await Future.delayed(const Duration(milliseconds: 500));
              debugPrint('Retry deleting history... (attempt ${retries + 1})');
            } else {
              rethrow;
            }
          }
        }

        // Wait for Firebase sync and propagation
        await Future.delayed(const Duration(seconds: 1));

        if (!mounted) return;

        // Update local state
        setState(() => history = []);

        // Reload from Firebase to confirm deletion
        await _loadHistory();

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ History cleared successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing history: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Map<String, int> _getProgressData() {
    // Use deduplicated history (only one entry per medicine per day)
    final deduplicatedHistory = _getFilteredHistory();
    final taken = deduplicatedHistory.where((h) => h.status == 'taken').length;
    final missed = deduplicatedHistory
        .where((h) => h.status == 'missed')
        .length;
    return {'taken': taken, 'missed': missed};
  }

  @override
  Widget build(BuildContext context) {
    final filteredHistory = _getFilteredHistory();
    final progressData = _getProgressData();
    final total = progressData['taken']! + progressData['missed']!;
    final takenPercentage = total > 0
        ? (progressData['taken']! / total * 100)
        : 0;

    return Scaffold(
      appBar: PreferredSize(preferredSize: Size.zero, child: Container()),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Progress Chart Card
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      color: Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue.shade50,
                              Colors.blue.shade100.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with Icon
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.blue.shade300,
                                          Colors.blue.shade600,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.trending_up,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Medicine Progress',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Your medication adherence',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              // Completion Rate Section
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: Colors.white.withValues(alpha: 0.6),
                                  border: Border.all(
                                    color: Colors.blue.shade100,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Completion Rate',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        Text(
                                          '${takenPercentage.toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: total > 0
                                            ? (takenPercentage / 100)
                                            : 0,
                                        minHeight: 12,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.green.shade400,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Stats Grid (3 cards)
                              GridView.count(
                                crossAxisCount: 3,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.2,
                                children: [
                                  _buildProgressStatCard(
                                    'Taken',
                                    progressData['taken'].toString(),
                                    Colors.green,
                                    Icons.check_circle,
                                  ),
                                  _buildProgressStatCard(
                                    'Missed',
                                    progressData['missed'].toString(),
                                    Colors.red,
                                    Icons.cancel,
                                  ),
                                  _buildProgressStatCard(
                                    'Total',
                                    total.toString(),
                                    Colors.blue,
                                    Icons.calendar_today,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Clear History Button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade500,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed: _clearAllHistory,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Clear All History',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'All'),
                        const SizedBox(width: 8),
                        _buildFilterChip('taken', 'Taken', Colors.green),
                        const SizedBox(width: 8),
                        _buildFilterChip('missed', 'Missed', Colors.red),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // History List
                  if (filteredHistory.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
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
                  else
                    ListView.builder(
                      itemCount: filteredHistory.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemBuilder: (context, index) {
                        final item = filteredHistory[index];
                        return _buildHistoryCard(item);
                      },
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, statusColor.withValues(alpha: 0.05)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
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
              const SizedBox(width: 12),
              // Medicine Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.medicineName}$doseInfo',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dosage: ${item.dosage}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
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
