import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class FirebaseOperations {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Write data to Firebase Realtime Database with detailed error handling
  static Future<void> writeData(String path, Map<String, dynamic> data) async {
    try {
      DatabaseReference dbRef = _db.ref(path);
      await dbRef.set(data);
      debugPrint('✓ Data written successfully to: $path');
      debugPrint('  Data: $data');
    } catch (e) {
      debugPrint('✗ Error writing to $path:');
      debugPrint('  Error: $e');
      if (e.toString().contains('PERMISSION_DENIED')) {
        debugPrint('  → Check your Realtime Database Rules!');
      }
      rethrow;
    }
  }

  /// Test Firebase connection
  static Future<void> testConnection() async {
    try {
      debugPrint('🔍 Testing Firebase connection...');
      debugPrint('📍 Database URL: ${_db.databaseURL}');
      debugPrint('📍 Reference URL: ${_db.ref().toString()}');

      DatabaseReference testRef = _db.ref('.info/connected');
      debugPrint('📍 Test ref: ${testRef.toString()}');

      final snapshot = await testRef.get();
      if (snapshot.exists) {
        debugPrint('✓ Connected to Firebase: ${snapshot.value}');
      } else {
        debugPrint('✗ Not connected to Firebase');
      }
    } catch (e) {
      debugPrint('✗ Connection test failed: $e');
      debugPrint('✗ Error details: ${e.runtimeType}');
    }
  }

  /// Read data from Firebase
  static Future<dynamic> readData(String path) async {
    try {
      DatabaseReference dbRef = _db.ref(path);
      final snapshot = await dbRef.get();
      if (snapshot.exists) {
        debugPrint('✓ Data read from $path: ${snapshot.value}');
        return snapshot.value;
      } else {
        debugPrint('✗ No data found at $path');
        return null;
      }
    } catch (e) {
      debugPrint('✗ Error reading from $path: $e');
      rethrow;
    }
  }

  /// Delete data at a given path (remove node)
  static Future<void> deleteData(String path) async {
    try {
      DatabaseReference dbRef = _db.ref(path);
      await dbRef.remove();
      debugPrint('✓ Data removed successfully from: $path');
    } catch (e) {
      debugPrint('✗ Error removing data at $path: $e');
      rethrow;
    }
  }
}
