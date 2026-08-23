class WorkoutExercise {
  final String name;
  final int sets;
  final String reps;
  final int restSeconds;
  final String? notes;

  WorkoutExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.notes,
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutExercise(
        name: json['name'] as String? ?? '',
        sets: (json['sets'] as num?)?.toInt() ?? 0,
        reps: json['reps']?.toString() ?? '',
        restSeconds: (json['rest_seconds'] as num?)?.toInt() ?? 0,
        notes: json['notes'] as String?,
      );
}

class WorkoutDay {
  final String id;
  final int dayNumber;
  final String name;
  final int estimatedDurationMin;
  final List<WorkoutExercise> exercises;

  WorkoutDay({
    required this.id,
    required this.dayNumber,
    required this.name,
    required this.estimatedDurationMin,
    required this.exercises,
  });

  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
    id: json['id'].toString(),
    dayNumber: (json['day_number'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    estimatedDurationMin:
        (json['estimated_duration_min'] as num?)?.toInt() ?? 0,
    exercises:
        ((json['exercises'] as List?) ?? [])
            .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
  );
}

class ActiveProgram {
  final String id;
  final String name;
  final String description;
  final List<WorkoutDay> workouts;

  ActiveProgram({
    required this.id,
    required this.name,
    required this.description,
    required this.workouts,
  });
}
