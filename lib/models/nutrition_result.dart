class NutritionResult {
  final String foodName;
  final String portionEstimate;
  final double portionGrams;    // Absolute grams from AI or barcode
  final double portionMultiplier; // Multiplier relative to portionGrams (slider)

  // Base nutritional values per portionGrams
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  // Key Micronutrients
  final double vitaminA; // mcg
  final double vitaminC; // mg
  final double vitaminD; // mcg
  final double calcium;  // mg
  final double iron;     // mg
  final double potassium; // mg

  // Source tag for display
  final String source; // 'gemini+usda' | 'barcode' | 'cache' | 'mock'
  final String? photoUrl;

  NutritionResult({
    required this.foodName,
    required this.portionEstimate,
    this.portionGrams = 100.0,
    this.portionMultiplier = 1.0,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.vitaminA = 0.0,
    this.vitaminC = 0.0,
    this.vitaminD = 0.0,
    this.calcium = 0.0,
    this.iron = 0.0,
    this.potassium = 0.0,
    this.source = 'mock',
    this.photoUrl,
  });

  NutritionResult copyWith({
    String? foodName,
    String? portionEstimate,
    double? portionGrams,
    double? portionMultiplier,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? vitaminA,
    double? vitaminC,
    double? vitaminD,
    double? calcium,
    double? iron,
    double? potassium,
    String? source,
    String? photoUrl,
  }) {
    return NutritionResult(
      foodName: foodName ?? this.foodName,
      portionEstimate: portionEstimate ?? this.portionEstimate,
      portionGrams: portionGrams ?? this.portionGrams,
      portionMultiplier: portionMultiplier ?? this.portionMultiplier,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      vitaminA: vitaminA ?? this.vitaminA,
      vitaminC: vitaminC ?? this.vitaminC,
      vitaminD: vitaminD ?? this.vitaminD,
      calcium: calcium ?? this.calcium,
      iron: iron ?? this.iron,
      potassium: potassium ?? this.potassium,
      source: source ?? this.source,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
