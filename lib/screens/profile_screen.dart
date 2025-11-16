import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../firebase_operations.dart';
import '../models/medicine_history.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditMode = false;
  bool _isLoading = true;
  String? _userId;

  // Auto-generated health data
  int _totalMedicines = 0;
  double _adherenceRate = 0.0;
  StreamSubscription<DatabaseEvent>? _historySubscription;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _generateHealthData();
    _setupHistoryListener();
  }

  Future<void> _generateHealthData() async {
    try {
      // Get medicines count
      final medicinesData = await FirebaseOperations.readData('medicines');
      if (medicinesData != null && medicinesData is Map) {
        setState(() => _totalMedicines = medicinesData.length);
      }

      // Get this month's history
      final historyData = await FirebaseOperations.readData('medicine_history');
      if (historyData != null && historyData is Map) {
        final now = DateTime.now();
        int completed = 0;
        int total = 0;

        // Deduplicate by medicine + date (only count latest entry per day per medicine)
        final Map<String, MedicineHistory> uniqueByDay = {};

        for (var entry in historyData.entries) {
          try {
            final h = MedicineHistory.fromMap(
              Map<String, dynamic>.from(entry.value),
            );
            final dt = h.dateTaken;

            // Check if in this month
            if (dt.year == now.year && dt.month == now.month) {
              final dateKey =
                  '${h.medicineName}_${dt.year}-${dt.month}-${dt.day}';
              // Keep the most recent entry for each medicine per day
              if (!uniqueByDay.containsKey(dateKey) ||
                  h.dateTaken.isAfter(uniqueByDay[dateKey]!.dateTaken)) {
                uniqueByDay[dateKey] = h;
              }
            }
          } catch (_) {}
        }

        // Count unique entries
        for (var h in uniqueByDay.values) {
          total++;
          if (h.status == 'taken') completed++;
        }

        setState(() {
          _adherenceRate = total > 0 ? (completed / total * 100) : 0.0;
        });
      }
    } catch (e) {
      debugPrint('Error generating health data: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final userData = await FirebaseOperations.readData('users');
      if (userData != null && userData is Map) {
        final firstUserKey = userData.keys.first;
        final user = userData[firstUserKey];
        if (user != null) {
          setState(() {
            _userId = firstUserKey;
            _nameController.text = user['name'] ?? '';
            _ageController.text = user['age']?.toString() ?? '';
            _emailController.text = user['email'] ?? '';
            _phoneController.text = user['phone'] ?? '';
            _isLoading = false;
          });
          debugPrint('✓ Profile loaded: ${user['email']}');
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUserProfile() async {
    try {
      if (_userId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No user found')));
        return;
      }

      final userData = {
        'email': _emailController.text,
        'name': _nameController.text,
        'age': int.tryParse(_ageController.text) ?? 0,
        'phone': _phoneController.text,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await FirebaseOperations.writeData('users/$_userId', userData);
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Profile updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _isEditMode = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userKey');
      if (!mounted) return;
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/auth', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  /// Set up real-time listener for history changes
  void _setupHistoryListener() {
    try {
      final ref = FirebaseDatabase.instance.ref('medicine_history');
      _historySubscription = ref.onValue.listen((event) async {
        // On any change, refresh health data
        await _generateHealthData();
      });
    } catch (e) {
      debugPrint('Error setting up history listener: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header with Avatar
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue.shade300, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  _nameController.text.isNotEmpty
                      ? _nameController.text
                      : 'User Profile',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _emailController.text,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() => _isEditMode = !_isEditMode);
                  },
                  icon: Icon(_isEditMode ? Icons.close : Icons.edit),
                  label: Text(
                    _isEditMode ? 'Cancel' : 'Edit Profile',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade500,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Logout', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Personal Information Section
          _buildSectionTitle('Personal Information'),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade50,
                      Colors.blue.shade100.withValues(alpha: 0.25),
                    ],
                  ),
                  border: Border.all(color: Colors.blue.shade100, width: 1),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildPersonalInfoField(
                      'Full Name',
                      _nameController,
                      Icons.person,
                      Icons.person,
                    ),
                    const SizedBox(height: 18),
                    Divider(
                      color: Colors.blue.shade100,
                      thickness: 1,
                      height: 1,
                    ),
                    const SizedBox(height: 18),
                    _buildPersonalInfoField(
                      'Age',
                      _ageController,
                      Icons.cake,
                      Icons.cake,
                    ),
                    const SizedBox(height: 18),
                    Divider(
                      color: Colors.blue.shade100,
                      thickness: 1,
                      height: 1,
                    ),
                    const SizedBox(height: 18),
                    _buildPersonalInfoField(
                      'Email',
                      _emailController,
                      Icons.email,
                      Icons.email,
                    ),
                    const SizedBox(height: 18),
                    Divider(
                      color: Colors.blue.shade100,
                      thickness: 1,
                      height: 1,
                    ),
                    const SizedBox(height: 18),
                    _buildPersonalInfoField(
                      'Phone',
                      _phoneController,
                      Icons.phone,
                      Icons.phone,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          const SizedBox(height: 14),

          // Health Insights
          _buildSectionTitle('Health Insights'),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade50,
                  Colors.green.shade100.withValues(alpha: 0.3),
                ],
              ),
              border: Border.all(color: Colors.green.shade200, width: 1.5),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getHealthInsight(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          if (_isEditMode)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: _saveUserProfile,
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoField(
    String label,
    TextEditingController controller,
    IconData displayIcon,
    IconData inputIcon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade200, Colors.blue.shade400],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(displayIcon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              _isEditMode
                  ? SizedBox(
                      height: 38,
                      child: TextField(
                        controller: controller,
                        enabled: _isEditMode,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.blue.shade200,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.blue.shade600,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.blue.shade200,
                              width: 1,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : Text(
                      controller.text.isNotEmpty ? controller.text : 'Not set',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: controller.text.isNotEmpty
                            ? Colors.black87
                            : Colors.grey.shade500,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  String _getHealthInsight() {
    if (_totalMedicines == 0) {
      return '📋 No medicines added yet. Start adding medicines to track your health!';
    }

    if (_adherenceRate >= 90) {
      return '🌟 Excellent! You\'re maintaining ${_adherenceRate.toStringAsFixed(0)}% adherence. Keep it up!';
    } else if (_adherenceRate >= 75) {
      return '👍 Good progress! Your adherence is ${_adherenceRate.toStringAsFixed(0)}%. Try to be more consistent.';
    } else if (_adherenceRate >= 50) {
      return '⚠️ Your adherence is ${_adherenceRate.toStringAsFixed(0)}%. Consider setting more reminders.';
    } else {
      return '💪 Let\'s improve! Track your medicines more consistently for better health outcomes.';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _historySubscription?.cancel();
    super.dispose();
  }
}
