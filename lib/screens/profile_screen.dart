import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_operations.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Get user ID from shared preference or auth (for now using a placeholder)
      // In production, get from authenticated user session
      final userData = await FirebaseOperations.readData('users');
      if (userData != null && userData is Map) {
        // Get first user (in production, filter by authenticated user)
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
          print('✓ Profile loaded: ${user['email']}');
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading profile: $e');
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Profile updated successfully!'),
            backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Avatar
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.person, size: 60, color: Colors.blue.shade600),
          ),
          const SizedBox(height: 20),
          // Edit Button
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _isEditMode = !_isEditMode);
            },
            icon: Icon(_isEditMode ? Icons.close : Icons.edit),
            label: Text(_isEditMode ? 'Cancel' : 'Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
            ),
          ),
          const SizedBox(height: 12),
          // Logout Button
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 24),
          // Profile Form
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade50,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileField('Full Name', _nameController, Icons.person),
                const SizedBox(height: 16),
                _buildProfileField('Age', _ageController, Icons.cake),
                const SizedBox(height: 16),
                _buildProfileField('Email', _emailController, Icons.email),
                const SizedBox(height: 16),
                _buildProfileField('Phone', _phoneController, Icons.phone),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Health Info Section
          const Text(
            'Health Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade50,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow('Account Created', 'Firebase Stored'),
                const SizedBox(height: 12),
                _buildInfoRow('Status', 'Active'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_isEditMode)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                ),
                onPressed: _saveUserProfile,
                child: const Text(
                  'Save Changes',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: _isEditMode,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
