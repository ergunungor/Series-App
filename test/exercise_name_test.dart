import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/utils/exercise_name.dart';

void main() {
  test('formatExerciseName', () {
    expect(formatExerciseName('barbell bench press'), 'Barbell Bench Press');
    expect(
      formatExerciseName('barbell close-grip bench press (male)'),
      'Barbell Close-Grip Bench Press (Male)',
    );
    expect(formatExerciseName('3/4 sit-up'), '3/4 Sit-Up');
    expect(formatExerciseName('45° side bend'), '45° Side Bend');
    expect(formatExerciseName("farmer's walk"), "Farmer's Walk");
    expect(formatExerciseName(''), '');
  });
}
