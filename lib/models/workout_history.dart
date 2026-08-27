class LoggedSet {
  final String exerciseName;
  final int setNumber;
  final int repsPerformed;
  final double weightUsed;

  LoggedSet({
    required this.exerciseName,
    required this.setNumber,
    required this.repsPerformed,
    required this.weightUsed,
  });

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
    exerciseName: json['exercise_name'] as String? ?? '',
    setNumber: (json['set_number'] as num?)?.toInt() ?? 0,
    repsPerformed: (json['reps_performed'] as num?)?.toInt() ?? 0,
    weightUsed: (json['weight_used'] as num?)?.toDouble() ?? 0,
  );
}

class WorkoutHistorySession {
  final String workoutId;
  final String workoutName;
  final DateTime completedAt;
  final List<LoggedSet> sets;

  WorkoutHistorySession({
    required this.workoutId,
    required this.workoutName,
    required this.completedAt,
    required this.sets,
  });

  int get exerciseCount => sets.map((s) => s.exerciseName).toSet().length;
  int get setCount => sets.length;
}
