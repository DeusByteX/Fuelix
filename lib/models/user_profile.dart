import '../utils/nutrition_calculator.dart';

class UserProfile {
  final String uid;
  final String email;
  final String name;
  final String gender; // 'Male' or 'Female'
  final int age;
  final double heightCm;
  final double weightKg;
  final double targetWeightKg;
  final List<String> primaryGoals; // Multi-select goals list
  final String activityLevel; // 'Sedentary' / 'Light' / 'Moderate' / 'Very active'
  final String dietaryPreference; // 'No restriction' / 'Vegetarian' / 'Vegan' / 'Keto' / 'Other'
  final int workoutDaysPerWeek;
  final List<String> allergies;
  final bool isMetric; // Toggle for unit preferences
  final bool isOnboarded; // Flag for onboarding completion
  final String themePreference; // 'dark' | 'light' | 'system'
  final String dietStrictness; // 'Strict' | 'Moderate'
  final bool isGymActive; // true | false

  // Calculated values cached in model
  final int dailyCalorieTarget;
  final int dailyProteinTarget;
  final int dailyCarbsTarget;
  final int dailyFatTarget;

  UserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.targetWeightKg,
    required this.primaryGoals,
    required this.activityLevel,
    required this.dietaryPreference,
    required this.workoutDaysPerWeek,
    required this.allergies,
    this.isMetric = true,
    this.isOnboarded = false,
    this.themePreference = 'dark',
    this.dietStrictness = 'Moderate',
    this.isGymActive = false,
    int? dailyCalorieTarget,
    int? dailyProteinTarget,
    int? dailyCarbsTarget,
    int? dailyFatTarget,
  })  : dailyCalorieTarget = dailyCalorieTarget ??
            NutritionCalculator.calculateMacros(
              weightKg: weightKg,
              heightCm: heightCm,
              age: age,
              isMale: gender.toLowerCase() == 'male',
              activityLevel: activityLevel,
              goals: primaryGoals,
              dietStrictness: dietStrictness,
              isGymActive: isGymActive,
            )['calories']!,
        dailyProteinTarget = dailyProteinTarget ??
            NutritionCalculator.calculateMacros(
              weightKg: weightKg,
              heightCm: heightCm,
              age: age,
              isMale: gender.toLowerCase() == 'male',
              activityLevel: activityLevel,
              goals: primaryGoals,
              dietStrictness: dietStrictness,
              isGymActive: isGymActive,
            )['protein']!,
        dailyCarbsTarget = dailyCarbsTarget ??
            NutritionCalculator.calculateMacros(
              weightKg: weightKg,
              heightCm: heightCm,
              age: age,
              isMale: gender.toLowerCase() == 'male',
              activityLevel: activityLevel,
              goals: primaryGoals,
              dietStrictness: dietStrictness,
              isGymActive: isGymActive,
            )['carbs']!,
        dailyFatTarget = dailyFatTarget ??
            NutritionCalculator.calculateMacros(
              weightKg: weightKg,
              heightCm: heightCm,
              age: age,
              isMale: gender.toLowerCase() == 'male',
              activityLevel: activityLevel,
              goals: primaryGoals,
              dietStrictness: dietStrictness,
              isGymActive: isGymActive,
            )['fat']!;

  UserProfile copyWith({
    String? uid,
    String? email,
    String? name,
    String? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    List<String>? primaryGoals,
    String? activityLevel,
    String? dietaryPreference,
    int? workoutDaysPerWeek,
    List<String>? allergies,
    bool? isMetric,
    bool? isOnboarded,
    String? themePreference,
    String? dietStrictness,
    bool? isGymActive,
  }) {
    // Dynamic recalculation of macros if physical attributes or goals change
    final newWeight = weightKg ?? this.weightKg;
    final newHeight = heightCm ?? this.heightCm;
    final newAge = age ?? this.age;
    final newGender = gender ?? this.gender;
    final newActivity = activityLevel ?? this.activityLevel;
    final newGoals = primaryGoals ?? this.primaryGoals;
    final newStrictness = dietStrictness ?? this.dietStrictness;
    final newGym = isGymActive ?? this.isGymActive;

    final targets = NutritionCalculator.calculateMacros(
      weightKg: newWeight,
      heightCm: newHeight,
      age: newAge,
      isMale: newGender.toLowerCase() == 'male',
      activityLevel: newActivity,
      goals: newGoals,
      dietStrictness: newStrictness,
      isGymActive: newGym,
    );

    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      gender: newGender,
      age: newAge,
      heightCm: newHeight,
      weightKg: newWeight,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      primaryGoals: newGoals,
      activityLevel: newActivity,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      workoutDaysPerWeek: workoutDaysPerWeek ?? this.workoutDaysPerWeek,
      allergies: allergies ?? this.allergies,
      isMetric: isMetric ?? this.isMetric,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      themePreference: themePreference ?? this.themePreference,
      dietStrictness: newStrictness,
      isGymActive: newGym,
      dailyCalorieTarget: targets['calories']!,
      dailyProteinTarget: targets['protein']!,
      dailyCarbsTarget: targets['carbs']!,
      dailyFatTarget: targets['fat']!,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'gender': gender,
      'age': age,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'targetWeightKg': targetWeightKg,
      'primaryGoals': primaryGoals,
      'activityLevel': activityLevel,
      'dietaryPreference': dietaryPreference,
      'workoutDaysPerWeek': workoutDaysPerWeek,
      'allergies': allergies,
      'isMetric': isMetric,
      'isOnboarded': isOnboarded,
      'theme_preference': themePreference,
      'dietStrictness': dietStrictness,
      'isGymActive': isGymActive,
      'dailyCalorieTarget': dailyCalorieTarget,
      'dailyProteinTarget': dailyProteinTarget,
      'dailyCarbsTarget': dailyCarbsTarget,
      'dailyFatTarget': dailyFatTarget,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    // Graceful backward compatibility mapping
    final List<String> goalsList = map['primaryGoals'] != null
        ? List<String>.from(map['primaryGoals'])
        : (map['primaryGoal'] != null ? [map['primaryGoal'] as String] : ['Maintain']);

    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      gender: map['gender'] ?? 'Male',
      age: (map['age'] as num?)?.toInt() ?? 25,
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 170.0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 70.0,
      targetWeightKg: (map['targetWeightKg'] as num?)?.toDouble() ?? 70.0,
      primaryGoals: goalsList,
      activityLevel: map['activityLevel'] ?? 'Moderate',
      dietaryPreference: map['dietaryPreference'] ?? 'No restriction',
      workoutDaysPerWeek: (map['workoutDaysPerWeek'] as num?)?.toInt() ?? 3,
      allergies: List<String>.from(map['allergies'] ?? []),
      isMetric: map['isMetric'] ?? true,
      isOnboarded: map['isOnboarded'] ?? false,
      themePreference: map['theme_preference'] ?? 'dark',
      dietStrictness: map['dietStrictness'] ?? 'Moderate',
      isGymActive: map['isGymActive'] ?? false,
      dailyCalorieTarget: (map['dailyCalorieTarget'] as num?)?.toInt(),
      dailyProteinTarget: (map['dailyProteinTarget'] as num?)?.toInt(),
      dailyCarbsTarget: (map['dailyCarbsTarget'] as num?)?.toInt(),
      dailyFatTarget: (map['dailyFatTarget'] as num?)?.toInt(),
    );
  }
}
