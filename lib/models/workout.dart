class ExerciseSet {
  final int setNumber;
  final int reps;
  final double weight; // Can be kg or lbs based on user units
  final bool isCompleted;

  ExerciseSet({
    required this.setNumber,
    required this.reps,
    required this.weight,
    this.isCompleted = false,
  });

  ExerciseSet copyWith({
    int? setNumber,
    int? reps,
    double? weight,
    bool? isCompleted,
  }) {
    return ExerciseSet(
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'setNumber': setNumber,
      'reps': reps,
      'weight': weight,
      'isCompleted': isCompleted,
    };
  }

  factory ExerciseSet.fromMap(Map<String, dynamic> map) {
    return ExerciseSet(
      setNumber: map['setNumber'] ?? 1,
      reps: map['reps'] ?? 10,
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class Exercise {
  final String name;
  final String category; // e.g. 'Chest', 'Legs', 'Cardio'
  final List<ExerciseSet> sets;

  Exercise({
    required this.name,
    required this.category,
    required this.sets,
  });

  Exercise copyWith({
    String? name,
    String? category,
    List<ExerciseSet>? sets,
  }) {
    return Exercise(
      name: name ?? this.name,
      category: category ?? this.category,
      sets: sets ?? this.sets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'sets': sets.map((x) => x.toMap()).toList(),
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      name: map['name'] ?? '',
      category: map['category'] ?? 'General',
      sets: List<ExerciseSet>.from(
        (map['sets'] ?? []).map((x) => ExerciseSet.fromMap(x)),
      ),
    );
  }
}

class WorkoutSession {
  final String id;
  final String userId;
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final List<Exercise> exercises;
  final bool isCompleted;

  WorkoutSession({
    required this.id,
    required this.userId,
    required this.name,
    required this.startTime,
    this.endTime,
    required this.exercises,
    this.isCompleted = false,
  });

  WorkoutSession copyWith({
    String? id,
    String? userId,
    String? name,
    DateTime? startTime,
    DateTime? endTime,
    List<Exercise>? exercises,
    bool? isCompleted,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      exercises: exercises ?? this.exercises,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'exercises': exercises.map((x) => x.toMap()).toList(),
      'isCompleted': isCompleted,
    };
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      startTime: map['startTime'] != null ? DateTime.parse(map['startTime']) : DateTime.now(),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      exercises: List<Exercise>.from(
        (map['exercises'] ?? []).map((x) => Exercise.fromMap(x)),
      ),
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class BurnedActivity {
  final String id;
  final String userId;
  final String name;
  final double durationMinutes;
  final String intensity; // 'Low' | 'Moderate' | 'Extreme'
  final bool carriesExtraLoad;
  final int caloriesBurned;
  final DateTime timestamp;

  BurnedActivity({
    required this.id,
    required this.userId,
    required this.name,
    required this.durationMinutes,
    required this.intensity,
    required this.carriesExtraLoad,
    required this.caloriesBurned,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'durationMinutes': durationMinutes,
      'intensity': intensity,
      'carriesExtraLoad': carriesExtraLoad,
      'caloriesBurned': caloriesBurned,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory BurnedActivity.fromMap(Map<String, dynamic> map) {
    return BurnedActivity(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      durationMinutes: (map['durationMinutes'] as num?)?.toDouble() ?? 0.0,
      intensity: map['intensity'] ?? 'Moderate',
      carriesExtraLoad: map['carriesExtraLoad'] ?? false,
      caloriesBurned: (map['caloriesBurned'] as num?)?.toInt() ?? 0,
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : DateTime.now(),
    );
  }
}
