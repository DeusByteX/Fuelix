class MealLog {
  final String id;
  final String userId;
  final DateTime date; // Store date of logging
  final String name;
  final String mealCategory; // 'Breakfast', 'Lunch', 'Dinner', 'Snacks'
  
  // Base nutrients for standard portion size
  final double baseCalories;
  final double baseProtein;
  final double baseCarbs;
  final double baseFat;
  
  // Key Micronutrients
  final double baseVitaminA; // in mcg RAE
  final double baseVitaminC; // in mg
  final double baseVitaminD; // in mcg
  final double baseCalcium; // in mg
  final double baseIron; // in mg
  final double basePotassium; // in mg
  
  final double portionSizeMultiplier; // Multiplier from slider (e.g. 1.0, 1.5)
  final String portionUnit; // e.g. "serving", "grams" or "oz"

  MealLog({
    required this.id,
    required this.userId,
    required this.date,
    required this.name,
    required this.mealCategory,
    required this.baseCalories,
    required this.baseProtein,
    required this.baseCarbs,
    required this.baseFat,
    this.baseVitaminA = 0.0,
    this.baseVitaminC = 0.0,
    this.baseVitaminD = 0.0,
    this.baseCalcium = 0.0,
    this.baseIron = 0.0,
    this.basePotassium = 0.0,
    this.portionSizeMultiplier = 1.0,
    this.portionUnit = 'serving',
  });

  // Dynamically calculated nutrients based on portion multiplier
  double get calories => baseCalories * portionSizeMultiplier;
  double get protein => baseProtein * portionSizeMultiplier;
  double get carbs => baseCarbs * portionSizeMultiplier;
  double get fat => baseFat * portionSizeMultiplier;
  
  double get vitaminA => baseVitaminA * portionSizeMultiplier;
  double get vitaminC => baseVitaminC * portionSizeMultiplier;
  double get vitaminD => baseVitaminD * portionSizeMultiplier;
  double get calcium => baseCalcium * portionSizeMultiplier;
  double get iron => baseIron * portionSizeMultiplier;
  double get potassium => basePotassium * portionSizeMultiplier;

  MealLog copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? name,
    String? mealCategory,
    double? baseCalories,
    double? baseProtein,
    double? baseCarbs,
    double? baseFat,
    double? baseVitaminA,
    double? baseVitaminC,
    double? baseVitaminD,
    double? baseCalcium,
    double? baseIron,
    double? basePotassium,
    double? portionSizeMultiplier,
    String? portionUnit,
  }) {
    return MealLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      name: name ?? this.name,
      mealCategory: mealCategory ?? this.mealCategory,
      baseCalories: baseCalories ?? this.baseCalories,
      baseProtein: baseProtein ?? this.baseProtein,
      baseCarbs: baseCarbs ?? this.baseCarbs,
      baseFat: baseFat ?? this.baseFat,
      baseVitaminA: baseVitaminA ?? this.baseVitaminA,
      baseVitaminC: baseVitaminC ?? this.baseVitaminC,
      baseVitaminD: baseVitaminD ?? this.baseVitaminD,
      baseCalcium: baseCalcium ?? this.baseCalcium,
      baseIron: baseIron ?? this.baseIron,
      basePotassium: basePotassium ?? this.basePotassium,
      portionSizeMultiplier: portionSizeMultiplier ?? this.portionSizeMultiplier,
      portionUnit: portionUnit ?? this.portionUnit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'name': name,
      'mealCategory': mealCategory,
      'baseCalories': baseCalories,
      'baseProtein': baseProtein,
      'baseCarbs': baseCarbs,
      'baseFat': baseFat,
      'baseVitaminA': baseVitaminA,
      'baseVitaminC': baseVitaminC,
      'baseVitaminD': baseVitaminD,
      'baseCalcium': baseCalcium,
      'baseIron': baseIron,
      'basePotassium': basePotassium,
      'portionSizeMultiplier': portionSizeMultiplier,
      'portionUnit': portionUnit,
    };
  }

  factory MealLog.fromMap(Map<String, dynamic> map) {
    return MealLog(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      name: map['name'] ?? '',
      mealCategory: map['mealCategory'] ?? 'Breakfast',
      baseCalories: (map['baseCalories'] as num?)?.toDouble() ?? 0.0,
      baseProtein: (map['baseProtein'] as num?)?.toDouble() ?? 0.0,
      baseCarbs: (map['baseCarbs'] as num?)?.toDouble() ?? 0.0,
      baseFat: (map['baseFat'] as num?)?.toDouble() ?? 0.0,
      baseVitaminA: (map['baseVitaminA'] as num?)?.toDouble() ?? 0.0,
      baseVitaminC: (map['baseVitaminC'] as num?)?.toDouble() ?? 0.0,
      baseVitaminD: (map['baseVitaminD'] as num?)?.toDouble() ?? 0.0,
      baseCalcium: (map['baseCalcium'] as num?)?.toDouble() ?? 0.0,
      baseIron: (map['baseIron'] as num?)?.toDouble() ?? 0.0,
      basePotassium: (map['basePotassium'] as num?)?.toDouble() ?? 0.0,
      portionSizeMultiplier: (map['portionSizeMultiplier'] as num?)?.toDouble() ?? 1.0,
      portionUnit: map['portionUnit'] ?? 'serving',
    );
  }
}
