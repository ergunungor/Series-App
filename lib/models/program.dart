class WorkoutExercise {
  final String id; // Backend'den gelmeyen durumlarda boş string olabilir
  final String name;
  final int sets;
  final dynamic reps;
  final int? durationSeconds;
  final int? restSeconds;
  final String? notes;
  final String? instructions; // EKLENEN YENİ ALAN

  WorkoutExercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    this.durationSeconds,
    this.restSeconds,
    this.notes,
    this.instructions, // CONSTRUCTOR'A EKLENDİ
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      sets: json['sets'] ?? 1,
      reps: json['reps'] ?? '',
      durationSeconds: json['duration_seconds'],
      restSeconds: json['rest_seconds'],
      notes: json['notes'],
      instructions: json['instructions'], // JSON'DAN OKUMA EKLENDİ
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sets': sets,
      'reps': reps,
      'duration_seconds': durationSeconds,
      'rest_seconds': restSeconds,
      'notes': notes,
      'instructions': instructions, // JSON'A YAZMA EKLENDİ
    };
  }
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
