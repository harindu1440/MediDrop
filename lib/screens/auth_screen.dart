import 'package:flutter/material.dart';
import '../firebase_operations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade300, Colors.blue.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/medidrop.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.medication,
                      size: 50,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'MediDrop',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin ? 'Welcome Back' : 'Create Account',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),
                // Form
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Name field (register only)
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Email
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        // Password
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          obscureText: true,
                        ),
                        // Age field (register only)
                        if (!_isLogin) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _ageController,
                            decoration: InputDecoration(
                              labelText: 'Age',
                              prefixIcon: const Icon(Icons.cake),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _isLoading ? null : _handleAuth,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isLogin ? 'Login' : 'Register',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Toggle Login/Register
                TextButton(
                  onPressed: () {
                    setState(() => _isLogin = !_isLogin);
                    _emailController.clear();
                    _passwordController.clear();
                    _nameController.clear();
                    _ageController.clear();
                  },
                  child: Text(
                    _isLogin
                        ? 'Don\'t have account? Register'
                        : 'Already have account? Login',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleAuth() async {
    if (_isLogin) {
      _handleLogin();
    } else {
      _handleRegister();
    }
  }

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final emailKey = email.replaceAll('.', '_').replaceAll('@', '_at_');

      debugPrint('🔐 Logging in...');
      debugPrint('   Email: $email');
      debugPrint('   Firebase Key: $emailKey');

      final user = await FirebaseOperations.readData('users/$emailKey');
      if (!mounted) return;

      if (user != null) {
        if (user['password'] == _passwordController.text) {
          // Save user to local storage and navigate
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userKey', emailKey);
          if (!mounted) return;
          {
            debugPrint('✓ Login successful');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✓ Login successful!')),
            );
            Navigator.of(context).pushReplacementNamed('/home');
          }
        } else {
          debugPrint('✗ Invalid password');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid password')));
        }
      } else {
        debugPrint('✗ User not found');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not found')));
      }
    } catch (e) {
      debugPrint('✗ Login error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _handleRegister() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _ageController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Validate email format
      final email = _emailController.text.trim();
      if (!email.contains('@')) {
        throw Exception('Invalid email format');
      }

      // Firebase key cannot contain: . , $ # [ ] /
      // Replace . with _ in email to use as key
      final emailKey = email.replaceAll('.', '_').replaceAll('@', '_at_');

      final userData = {
        'email': email,
        'password': _passwordController.text,
        'name': _nameController.text,
        'age': int.parse(_ageController.text),
        'createdAt': DateTime.now().toIso8601String(),
      };

      debugPrint('📝 Registering user...');
      debugPrint('   Email: $email');
      debugPrint('   Firebase Key: $emailKey');

      await FirebaseOperations.writeData('users/$emailKey', userData);
      if (!mounted) return;

      if (mounted) {
        debugPrint('✓ User registered successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Account created! Please login.')),
        );
        setState(() => _isLogin = true);
        _emailController.clear();
        _passwordController.clear();
        _nameController.clear();
        _ageController.clear();
      }
    } catch (e) {
      debugPrint('✗ Registration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}
