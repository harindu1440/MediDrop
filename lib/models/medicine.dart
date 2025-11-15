class Medicine {
  final String id;
  final String name;
  final String dosage;
  final String frequency;
  final String time;
  final List<String> times;
  final DateTime dateAdded;

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.time,
    List<String>? times,
    required this.dateAdded,
  }) : times = times ?? [time];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'time': time,
      'times': times,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    // read times if available, otherwise fall back to single time
    final timesFromMap = map['times'] is List
        ? List<String>.from(map['times'])
        : null;
    final singleTime = map['time'] ?? '';
    return Medicine(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      time: singleTime,
      times: timesFromMap ?? (singleTime.isNotEmpty ? [singleTime] : []),
      dateAdded: DateTime.parse(
        map['dateAdded'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
