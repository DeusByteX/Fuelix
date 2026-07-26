class NutritionCalculator {
  /// Calculates BMR using Mifflin-St Jeor Equation
  static double calculateBMR({
    required double weightKg,
    required double heightCm,
    required int age,
    required bool isMale,
  }) {
    if (isMale) {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    } else {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    }
  }

  /// Calculates TDEE based on BMR and Activity Level
  static double calculateTDEE({
    required double bmr,
    required String activityLevel,
  }) {
    double multiplier;
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        multiplier = 1.2;
        break;
      case 'light':
      case 'lightly active':
        multiplier = 1.375;
        break;
      case 'moderate':
      case 'moderately active':
        multiplier = 1.55;
        break;
      case 'very active':
      case 'active':
        multiplier = 1.725;
        break;
      default:
        multiplier = 1.2;
    }
    return bmr * multiplier;
  }

  /// Calculates Calories and Macro splits based on weight, height, age, gender, activity level, and goals
  /// Returns a map containing:
  /// - 'calories': Daily Calorie Target (kcal)
  /// - 'protein': Daily Protein Target (grams)
  /// - 'carbs': Daily Carbs Target (grams)
  /// - 'fat': Daily Fat Target (grams)
  static Map<String, int> calculateMacros({
    required double weightKg,
    required double heightCm,
    required int age,
    required bool isMale,
    required String activityLevel,
    required List<String> goals,
    String dietStrictness = 'Moderate',
    bool isGymActive = false,
  }) {
    final bmr = calculateBMR(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      isMale: isMale,
    );

    final tdee = calculateTDEE(bmr: bmr, activityLevel: activityLevel);

    double calorieTarget = tdee;
    double pPct = 0.20;
    double cPct = 0.50;
    double fPct = 0.30;

    final lowerGoals = goals.map((g) => g.toLowerCase()).toList();

    // Check for Body Recomposition blend (Lose weight + Build muscle)
    if (lowerGoals.contains('lose weight') && lowerGoals.contains('build muscle')) {
      // Recomposition: slight deficit, high protein
      calorieTarget = tdee - 200;
      pPct = 0.35;
      cPct = 0.35;
      fPct = 0.30;
    } else if (lowerGoals.contains('lose weight')) {
      calorieTarget = tdee - 500;
      pPct = 0.30;
      cPct = 0.40;
      fPct = 0.30;
    } else if (lowerGoals.contains('build muscle')) {
      calorieTarget = tdee + 300;
      pPct = 0.25;
      cPct = 0.50;
      fPct = 0.25;
    } else if (lowerGoals.contains('improve endurance')) {
      calorieTarget = tdee;
      pPct = 0.15;
      cPct = 0.55;
      fPct = 0.30;
    }

    // Strictness adjustment to calorie target
    if (dietStrictness.toLowerCase() == 'strict') {
      if (lowerGoals.contains('lose weight')) {
        calorieTarget -= 100; // More aggressive calorie deficit
      } else if (lowerGoals.contains('build muscle')) {
        calorieTarget -= 150; // Cleaner bulk ratio to minimize fat gains
      }
    }

    // Gym activity protein adjustment
    if (isGymActive) {
      pPct += 0.05; // Boost protein for muscle recovery
      cPct -= 0.05; // Taper carbs to balance
    }

    // Minimum target calorie safety margin (1200 kcal)
    if (calorieTarget < 1200) {
      calorieTarget = 1200;
    }

    // Convert percentages to grams
    final proteinGrams = (calorieTarget * pPct) / 4;
    final carbsGrams = (calorieTarget * cPct) / 4;
    final fatGrams = (calorieTarget * fPct) / 9;

    return {
      'calories': calorieTarget.round(),
      'protein': proteinGrams.round(),
      'carbs': carbsGrams.round(),
      'fat': fatGrams.round(),
    };
  }
}
