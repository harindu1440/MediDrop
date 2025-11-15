import 'package:firebase_database/firebase_database.dart';

class FirebaseOperations {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Write data to Firebase Realtime Database with detailed error handling
  static Future<void> writeData(String path, Map<String, dynamic> data) async {
    try {
      DatabaseReference dbRef = _db.ref(path);
      await dbRef.set(data);
      print('✓ Data written successfully to: $path');
      print('  Data: $data');
    } catch (e) {
      print('✗ Error writing to $path:');
      print('  Error: $e');
      if (e.toString().contains('PERMISSION_DENIED')) {
        print('  → Check your Realtime Database Rules!');
      }
      rethrow;
    }
  }

  /// Test Firebase connection
  static Future<void> testConnection() async {
    try {
      print('🔍 Testing Firebase connection...');
      print('📍 Database URL: ${_db.databaseURL}');
      print('📍 Reference URL: ${_db.ref().toString()}');

      DatabaseReference testRef = _db.ref('.info/connected');
      print('📍 Test ref: ${testRef.toString()}');

      final snapshot = await testRef.get();
      if (snapshot.exists) {
        print('✓ Connected to Firebase: ${snapshot.value}');
      } else {
        print('✗ Not connected to Firebase');
      }
    } catch (e) {
      print('✗ Connection test failed: $e');
      print('✗ Error details: ${e.runtimeType}');
    }
  }

  /// Read data from Firebase
  static Future<dynamic> readData(String path) async {
    try {
      DatabaseReference dbRef = _db.ref(path);
      final snapshot = await dbRef.get();
      if (snapshot.exists) {
        print('✓ Data read from $path: ${snapshot.value}');
        return snapshot.value;
      } else {
        print('✗ No data found at $path');
        return null;
      }
    } catch (e) {
      print('✗ Error reading from $path: $e');
      rethrow;
    }
  }

  /// Delete data at a given path (remove node)
  static Future<void> deleteData(String path) async {
    try {
      DatabaseReference dbRef = _db.ref(path);
      await dbRef.remove();
      print('✓ Data removed successfully from: $path');
    } catch (e) {
      print('✗ Error removing data at $path: $e');
      rethrow;
    }
  }
}
