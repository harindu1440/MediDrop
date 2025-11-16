import 'package:firebase_database/firebase_database.dart';
import '../models/liquid_level.dart';
import 'package:flutter/foundation.dart';

class LiquidLevelService {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;
  static const String _basePath = 'liquid_levels';

  /// Get or create the default liquid level for the single medicine bottle
  static Future<LiquidLevel> getDefaultBottle() async {
    try {
      final snapshot = await _db.ref('$_basePath/bottle_001').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return LiquidLevel.fromMap(data);
      } else {
        // Create default bottle if it doesn't exist
        final defaultBottle = LiquidLevel(
          id: 'bottle_001',
          bottleName: 'Main Medicine Bottle',
          capacity: 500.0, // 500ml capacity
          currentLevel: 250.0, // Start at 50%
          lastUpdated: DateTime.now(),
          sensorId: 'ESP86_001',
        );
        await writeLiquidLevel(defaultBottle);
        return defaultBottle;
      }
    } catch (e) {
      debugPrint('Error getting default bottle: $e');
      rethrow;
    }
  }

  /// Write liquid level data to Firebase
  static Future<void> writeLiquidLevel(LiquidLevel liquidLevel) async {
    try {
      await _db.ref('$_basePath/${liquidLevel.id}').set(liquidLevel.toMap());
      debugPrint('✓ Liquid level updated: ${liquidLevel.bottleName}');
    } catch (e) {
      debugPrint('✗ Error writing liquid level: $e');
      rethrow;
    }
  }

  /// Read liquid level data from Firebase
  static Future<LiquidLevel?> readLiquidLevel(String bottleId) async {
    try {
      final snapshot = await _db.ref('$_basePath/$bottleId').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return LiquidLevel.fromMap(data);
      }
      return null;
    } catch (e) {
      debugPrint('✗ Error reading liquid level: $e');
      rethrow;
    }
  }

  /// Stream of liquid level updates for real-time listening
  static Stream<LiquidLevel> streamLiquidLevel(String bottleId) {
    return _db.ref('$_basePath/$bottleId').onValue.map((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return LiquidLevel.fromMap(data);
      }
      throw Exception('Bottle not found');
    });
  }

  /// Update current liquid level (from ESP86 sensor)
  static Future<void> updateLiquidLevel(
    String bottleId,
    double newLevel,
  ) async {
    try {
      final currentBottle = await readLiquidLevel(bottleId);
      if (currentBottle != null) {
        final updated = currentBottle.copyWith(
          currentLevel: newLevel,
          lastUpdated: DateTime.now(),
        );
        await writeLiquidLevel(updated);
        debugPrint(
          '✓ Liquid level updated to: ${newLevel.toStringAsFixed(2)}ml',
        );
      }
    } catch (e) {
      debugPrint('✗ Error updating liquid level: $e');
      rethrow;
    }
  }

  /// Delete liquid level record
  static Future<void> deleteLiquidLevel(String bottleId) async {
    try {
      await _db.ref('$_basePath/$bottleId').remove();
      debugPrint('✓ Liquid level record deleted: $bottleId');
    } catch (e) {
      debugPrint('✗ Error deleting liquid level: $e');
      rethrow;
    }
  }
}
