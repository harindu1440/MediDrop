class LiquidLevel {
  final String id;
  final String bottleName;
  final double capacity; // Total capacity in ml
  final double currentLevel; // Current level in ml
  final DateTime lastUpdated;
  final String sensorId; // ESP86 sensor ID

  LiquidLevel({
    required this.id,
    required this.bottleName,
    required this.capacity,
    required this.currentLevel,
    required this.lastUpdated,
    required this.sensorId,
  });

  /// Calculate percentage of liquid remaining
  double get percentageLevel => (currentLevel / capacity) * 100;

  /// Check if bottle is low on liquid (less than 20%)
  bool get isLow => percentageLevel < 20;

  /// Convert to Map for Firebase storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bottleName': bottleName,
      'capacity': capacity,
      'currentLevel': currentLevel,
      'percentageLevel': percentageLevel,
      'lastUpdated': lastUpdated.toIso8601String(),
      'sensorId': sensorId,
      'isLow': isLow,
    };
  }

  /// Create LiquidLevel from Map (Firebase data)
  factory LiquidLevel.fromMap(Map<String, dynamic> map) {
    return LiquidLevel(
      id: map['id'] as String? ?? '',
      bottleName: map['bottleName'] as String? ?? 'Medicine Bottle',
      capacity: (map['capacity'] as num?)?.toDouble() ?? 100.0,
      currentLevel: (map['currentLevel'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.parse(map['lastUpdated'] as String)
          : DateTime.now(),
      sensorId: map['sensorId'] as String? ?? '',
    );
  }

  /// Copy with method for creating modified instances
  LiquidLevel copyWith({
    String? id,
    String? bottleName,
    double? capacity,
    double? currentLevel,
    DateTime? lastUpdated,
    String? sensorId,
  }) {
    return LiquidLevel(
      id: id ?? this.id,
      bottleName: bottleName ?? this.bottleName,
      capacity: capacity ?? this.capacity,
      currentLevel: currentLevel ?? this.currentLevel,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      sensorId: sensorId ?? this.sensorId,
    );
  }
}
