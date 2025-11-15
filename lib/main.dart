import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notifications_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDZjpGnBfbsoAo27b9U6fJfV-dr4YJI3vI',
        appId: '1:177660195558:android:3644163dcd425ae5508127',
        messagingSenderId: '177660195558',
        projectId: 'medidrop-5c183',
        databaseURL: 'https://medidrop-5c183-default-rtdb.firebaseio.com',
        storageBucket: 'medidrop-5c183.firebasestorage.app',
      ),
    );
  } catch (e) {
    print('Firebase already initialized or error: $e');
  }

  // Initialize notifications
  await NotificationsService().initNotifications();

  // Load saved user (if any) to skip login
  final prefs = await SharedPreferences.getInstance();
  final savedUserKey = prefs.getString('userKey');

  runApp(MediDropApp(savedUserKey: savedUserKey));
}

class MediDropApp extends StatelessWidget {
  final String? savedUserKey;

  const MediDropApp({super.key, this.savedUserKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediDrop Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const SplashScreen(),
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
        '/splash': (context) => const SplashScreen(),
      },
    );
  }
}
