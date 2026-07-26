import 'package:flutter_test/flutter_test.dart';
import 'package:fuelix/utils/nutrition_calculator.dart';

void main() {
  group('NutritionCalculator Tests', () {
    test('BMR Men Calculation - Mifflin-St Jeor', () {
      // 10 * 70 + 6.25 * 175 - 5 * 25 + 5 = 700 + 1093.75 - 125 + 5 = 1673.75
      final bmr = NutritionCalculator.calculateBMR(
        weightKg: 70.0,
        heightCm: 175.0,
        age: 25,
        isMale: true,
      );
      expect(bmr, closeTo(1673.75, 0.01));
    });

    test('BMR Women Calculation - Mifflin-St Jeor', () {
      // 10 * 60 + 6.25 * 165 - 5 * 30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25
      final bmr = NutritionCalculator.calculateBMR(
        weightKg: 60.0,
        heightCm: 165.0,
        age: 30,
        isMale: false,
      );
      expect(bmr, closeTo(1320.25, 0.01));
    });

    test('TDEE Calculation', () {
      const bmr = 1500.0;
      
      final sedentary = NutritionCalculator.calculateTDEE(bmr: bmr, activityLevel: 'sedentary');
      expect(sedentary, 1500.0 * 1.2);

      final moderate = NutritionCalculator.calculateTDEE(bmr: bmr, activityLevel: 'moderate');
      expect(moderate, 1500.0 * 1.55);

      final veryActive = NutritionCalculator.calculateTDEE(bmr: bmr, activityLevel: 'very active');
      expect(veryActive, 1500.0 * 1.725);
    });

    test('Calorie and Macro Target Splitting', () {
      // Test Male, 80kg, 180cm, 30 years old, Moderately Active, Build Muscle
      // BMR = 10 * 80 + 6.25 * 180 - 5 * 30 + 5 = 800 + 1125 - 150 + 5 = 1780.0
      // TDEE = 1780 * 1.55 = 2759.0
      // Goal = Build Muscle -> TDEE + 300 = 3059.0
      // Macros: 50% Carbs, 25% Protein, 25% Fat
      // Protein: 3059 * 0.25 / 4 = 191.18g -> ~191g
      // Carbs: 3059 * 0.50 / 4 = 382.375g -> ~382g
      // Fat: 3059 * 0.25 / 9 = 84.97g -> ~85g

      final macros = NutritionCalculator.calculateMacros(
        weightKg: 80.0,
        heightCm: 180.0,
        age: 30,
        isMale: true,
        activityLevel: 'moderate',
        goals: const ['build muscle'],
      );

      expect(macros['calories'], 3059);
      expect(macros['protein'], 191);
      expect(macros['carbs'], 382);
      expect(macros['fat'], 85);
    });

    test('Safety Calorie Cap (1200 kcal)', () {
      // Test very light profile with weight loss deficit that would mathematically drop below 1200
      final macros = NutritionCalculator.calculateMacros(
        weightKg: 42.0,
        heightCm: 145.0,
        age: 65,
        isMale: false,
        activityLevel: 'sedentary',
        goals: const ['lose weight'],
      );
      
      expect(macros['calories'], greaterThanOrEqualTo(1200));
    });

    test('Body Recomposition Calculations (Multi-Goal Select)', () {
      // Test Male, 80kg, 180cm, 30 years old, Moderately Active, Lose Weight + Build Muscle
      // BMR = 10 * 80 + 6.25 * 180 - 5 * 30 + 5 = 800 + 1125 - 150 + 5 = 1780.0
      // TDEE = 1780 * 1.55 = 2759.0
      // Recomposition Deficit: TDEE - 200 = 2559.0
      // Split: 35% Protein, 35% Carbs, 30% Fat
      // Protein: 2559 * 0.35 / 4 = 223.9g -> ~224g
      // Carbs: 2559 * 0.35 / 4 = 223.9g -> ~224g
      // Fat: 2559 * 0.30 / 9 = 85.3g -> ~85g

      final macros = NutritionCalculator.calculateMacros(
        weightKg: 80.0,
        heightCm: 180.0,
        age: 30,
        isMale: true,
        activityLevel: 'moderate',
        goals: const ['Lose weight', 'Build muscle'],
      );

      expect(macros['calories'], 2559);
      expect(macros['protein'], 224);
      expect(macros['carbs'], 224);
      expect(macros['fat'], 85);
    });

    test('Strict Diet and Gym Activity Macro Adjustments', () {
      // Base: Male, 80kg, 180cm, 30yo, Moderate Active, Build Muscle
      // Base Calories: 3059 (BMR=1780, TDEE=2759 + 300 = 3059)
      // Strict: Bulking surplus reduced by 150 -> 2909
      // Gym: Protein ratio pPct boosted by 0.05 (0.25 -> 0.30), Carbs cPct reduced by 0.05 (0.50 -> 0.45)
      // Fat stays 0.25
      // Protein: 2909 * 0.30 / 4 = 218.175g -> ~218g
      // Carbs: 2909 * 0.45 / 4 = 327.26g -> ~327g
      // Fat: 2909 * 0.25 / 9 = 80.8g -> ~81g

      final macros = NutritionCalculator.calculateMacros(
        weightKg: 80.0,
        heightCm: 180.0,
        age: 30,
        isMale: true,
        activityLevel: 'moderate',
        goals: const ['build muscle'],
        dietStrictness: 'Strict',
        isGymActive: true,
      );

      expect(macros['calories'], 2909);
      expect(macros['protein'], 218);
      expect(macros['carbs'], 327);
      expect(macros['fat'], 81);
    });
  });
}
