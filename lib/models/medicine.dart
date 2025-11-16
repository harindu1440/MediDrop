class Medicine {
  final String id;
  final String name;
  final String dosage;
  final String frequency;
  final String time;
  final List<String> times;
  final DateTime dateAdded;
  final List<String> weeklyDays; // e.g., ['Monday', 'Wednesday', 'Friday']

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.time,
    List<String>? times,
    required this.dateAdded,
    List<String>? weeklyDays,
  }) : times = times ?? [time],
       weeklyDays =
           weeklyDays ??
           [
             'Monday',
             'Tuesday',
             'Wednesday',
             'Thursday',
             'Friday',
             'Saturday',
             'Sunday',
           ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'time': time,
      'times': times,
      'dateAdded': dateAdded.toIso8601String(),
      'weeklyDays': weeklyDays,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    // read times if available, otherwise fall back to single time
    final timesFromMap = map['times'] is List
        ? List<String>.from(map['times'] as List)
        : null;
    final singleTime = map['time'] ?? '';

    // Safely get weeklyDays with proper null handling
    List<String> daysFromMap = [];
    if (map['weeklyDays'] != null && map['weeklyDays'] is List) {
      try {
        daysFromMap = List<String>.from(map['weeklyDays'] as List);
      } catch (_) {
        daysFromMap = [];
      }
    }

    // Default days
    if (daysFromMap.isEmpty) {
      daysFromMap = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
    }

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
      weeklyDays: daysFromMap,
    );
  }
}
