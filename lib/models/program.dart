class WorkoutExercise {
  final String id; // Backend'den gelmeyen durumlarda boş string olabilir
  final String name;
  final int sets;
  final dynamic reps;
  final int? durationSeconds;
  final int? restSeconds;
  final String? notes;
  final String? instructions; // EKLENEN YENİ ALAN

  /// Aynı değere sahip ardışık hareketler süperset oluşturur (ara vermeden
  /// sırayla yapılır, mola turun sonunda). null = süperset değil.
  final int? supersetGroup;

  /// Her çalışma setinden sonra ara vermeden yapılacak ek düşük ağırlık
  /// seti sayısı (dropset). 0 = yok.
  final int dropSets;

  /// 'warmup' (ısınma), 'cooldown' (soğuma) ya da null (asıl antrenman).
  /// Isınma/soğumada tekrar ve kilo girilmez, kayıt tutulmaz.
  final String? section;

  bool get isWarmup => section == 'warmup';
  bool get isCooldown => section == 'cooldown';
  bool get isPrep => isWarmup || isCooldown;

  WorkoutExercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    this.durationSeconds,
    this.restSeconds,
    this.notes,
    this.instructions, // CONSTRUCTOR'A EKLENDİ
    this.supersetGroup,
    this.dropSets = 0,
    this.section,
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
      supersetGroup: (json['superset_group'] as num?)?.toInt(),
      dropSets: (json['drop_sets'] as num?)?.toInt() ?? 0,
      section: switch (json['section']) {
        'warmup' => 'warmup',
        'cooldown' => 'cooldown',
        _ => null,
      },
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
      if (supersetGroup != null) 'superset_group': supersetGroup,
      if (dropSets > 0) 'drop_sets': dropSets,
      if (section != null) 'section': section,
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
