class MedicineHistory {
  final String id;
  final String medicineId;
  final String medicineName;
  final String dosage;
  final DateTime dateTaken;
  final String status; // 'taken', 'missed', 'skipped'
  final int? doseIndex;
  final String? notes;

  MedicineHistory({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.dosage,
    required this.dateTaken,
    required this.status,
    this.doseIndex,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'dosage': dosage,
      'dateTaken': dateTaken.toIso8601String(),
      'status': status,
      'doseIndex': doseIndex,
      'notes': notes,
    };
  }

  factory MedicineHistory.fromMap(Map<String, dynamic> map) {
    return MedicineHistory(
      id: map['id'] ?? '',
      medicineId: map['medicineId'] ?? '',
      medicineName: map['medicineName'] ?? '',
      dosage: map['dosage'] ?? '',
      dateTaken: DateTime.parse(
        map['dateTaken'] ?? DateTime.now().toIso8601String(),
      ),
      status: map['status'] ?? 'taken',
      doseIndex: map['doseIndex'] is int
          ? map['doseIndex'] as int
          : (map['doseIndex'] is String
                ? int.tryParse(map['doseIndex'])
                : null),
      notes: map['notes'],
    );
  }
}
