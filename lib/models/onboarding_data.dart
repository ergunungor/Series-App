class LogisticsData {
  List<String> location;
  List<String> equipment; // Yeni eklenen alan
  int daysPerWeek;
  int maxDurationMin;

  LogisticsData({
    List<String>? location,
    List<String>? equipment, // Constructor'a eklendi
    this.daysPerWeek = 3,
    this.maxDurationMin = 45,
  }) : location = location ?? [],
       equipment = equipment ?? []; // Varsayılan boş liste ataması

  Map<String, dynamic> toJson() => {
    'location': location,
    'equipment': equipment, // JSON çıktısına eklendi
    'days_per_week': daysPerWeek,
    'max_duration_min': maxDurationMin,
  };
}

class OnboardingData {
  int? age;
  String? experience;
  String? primaryGoal;
  List<String> specificInterests;
  List<String> healthRestrictions;
  LogisticsData logistics;
  String? mentalBlocker;

  OnboardingData({
    this.age,
    this.experience,
    this.primaryGoal,
    List<String>? specificInterests,
    List<String>? healthRestrictions,
    LogisticsData? logistics,
    this.mentalBlocker,
  }) : specificInterests = specificInterests ?? [],
       healthRestrictions = healthRestrictions ?? [],
       logistics = logistics ?? LogisticsData();

  Map<String, dynamic> toJson(String userId) => {
    'user_id': userId,
    'age': age,
    'experience': experience,
    'primary_goal': primaryGoal,
    'specific_interests': specificInterests,
    'health_restrictions': healthRestrictions,
    'logistics': logistics.toJson(),
    'mental_blocker': mentalBlocker,
  };
}
