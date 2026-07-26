import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class NutritionApiService {
  final Dio _dio;
  final String _usdaApiKey;
  final bool _useMock;

  NutritionApiService({
    required Dio dio,
    required String usdaApiKey,
    bool useMock = false,
  })  : _dio = dio,
        _usdaApiKey = usdaApiKey,
        _useMock = useMock;

  /// Searches for a food item by name and fetches its nutrition data.
  /// Tries USDA FoodData Central first, falls back to Open Food Facts,
  /// and falls back to Mock Data if configured or if external calls fail.
  Future<Map<String, double>> fetchFoodNutrition(String foodName) async {
    if (_useMock || _usdaApiKey.isEmpty || _usdaApiKey == 'your_usda_api_key_here') {
      debugPrint("NutritionApiService: Using mock nutrition for '$foodName'");
      return _generateMockNutrition(foodName);
    }

    try {
      // 1. Try USDA FoodData Central API
      final usdaResult = await _queryUSDA(foodName);
      if (usdaResult != null) {
        return usdaResult;
      }

      // 2. Try Open Food Facts API (Fallback)
      final offResult = await _queryOpenFoodFacts(foodName);
      if (offResult != null) {
        return offResult;
      }
    } catch (e) {
      debugPrint("Nutrition API search error for '$foodName': $e. Falling back to mock data.");
    }

    // Dynamic mock fallback on failure so the user flow never breaks
    return _generateMockNutrition(foodName);
  }

  Future<Map<String, double>?> _queryUSDA(String query) async {
    try {
      final apiKey = _usdaApiKey == 'DEMO_KEY' ? 'DEMO_KEY' : _usdaApiKey;
      final response = await _dio.get(
        'https://api.nal.usda.gov/fdc/v1/foods/search',
        queryParameters: {
          'query': query,
          'pageSize': 1,
          'api_key': apiKey,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final List foods = response.data['foods'] ?? [];
        if (foods.isNotEmpty) {
          final food = foods.first;
          final List nutrients = food['foodNutrients'] ?? [];
          
          double calories = 0;
          double protein = 0;
          double carbs = 0;
          double fat = 0;
          double vitA = 0;
          double vitC = 0;
          double vitD = 0;
          double calcium = 0;
          double iron = 0;
          double potassium = 0;

          for (var nutr in nutrients) {
            final name = (nutr['nutrientName'] as String).toLowerCase();
            final value = (nutr['value'] as num?)?.toDouble() ?? 0.0;
            
            // Standard USDA Nutrient IDs/Names matching
            if (name.contains('energy') && nutr['unitName'].toString().toLowerCase() == 'kcal') {
              calories = value;
            } else if (name == 'protein') {
              protein = value;
            } else if (name.contains('carbohydrate')) {
              carbs = value;
            } else if (name.contains('lipid') || name == 'fat') {
              fat = value;
            } else if (name.contains('vitamin a')) {
              vitA = value; // mcg
            } else if (name.contains('vitamin c')) {
              vitC = value; // mg
            } else if (name.contains('vitamin d')) {
              vitD = value; // mcg
            } else if (name.contains('calcium')) {
              calcium = value; // mg
            } else if (name.contains('iron')) {
              iron = value; // mg
            } else if (name.contains('potassium')) {
              potassium = value; // mg
            }
          }

          // If calories weren't populated directly from energy kcal, estimate from macros
          if (calories == 0) {
            calories = (protein * 4) + (carbs * 4) + (fat * 9);
          }

          return {
            'calories': calories,
            'protein': protein,
            'carbs': carbs,
            'fat': fat,
            'vitaminA': vitA,
            'vitaminC': vitC,
            'vitaminD': vitD,
            'calcium': calcium,
            'iron': iron,
            'potassium': potassium,
          };
        }
      }
    } catch (e) {
      debugPrint("USDA API Error: $e");
    }
    return null;
  }

  Future<Map<String, double>?> _queryOpenFoodFacts(String query) async {
    try {
      final response = await _dio.get(
        'https://world.openfoodfacts.org/cgi/search.pl',
        queryParameters: {
          'search_terms': query,
          'json': 'true',
          'page_size': 1,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final List products = response.data['products'] ?? [];
        if (products.isNotEmpty) {
          final prod = products.first;
          final nutriments = prod['nutriments'] ?? {};

          double calories = (nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 
                            (nutriments['energy-kcal'] as num?)?.toDouble() ?? 0.0;
          double protein = (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0.0;
          double carbs = (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0;
          double fat = (nutriments['fat_100g'] as num?)?.toDouble() ?? 0.0;
          
          double vitA = (nutriments['vitamin-a_100g'] as num?)?.toDouble() ?? 0.0;
          double vitC = (nutriments['vitamin-c_100g'] as num?)?.toDouble() ?? 0.0;
          double vitD = (nutriments['vitamin-d_100g'] as num?)?.toDouble() ?? 0.0;
          double calcium = (nutriments['calcium_100g'] as num?)?.toDouble() ?? 0.0;
          double iron = (nutriments['iron_100g'] as num?)?.toDouble() ?? 0.0;
          double potassium = (nutriments['potassium_100g'] as num?)?.toDouble() ?? 0.0;

          // Convert grams to mg/mcg for micro if Open Food Facts reports in grams
          // E.g., Open Food Facts lists vitA/vitC/calcium in grams. Let's do a simple scaling.
          if (vitA < 1) vitA *= 1000000; // Grams to mcg
          if (vitC < 1 && vitC > 0) vitC *= 1000; // Grams to mg
          if (vitD < 1 && vitD > 0) vitD *= 1000000; // Grams to mcg
          if (calcium < 1 && calcium > 0) calcium *= 1000; // Grams to mg
          if (iron < 1 && iron > 0) iron *= 1000; // Grams to mg
          if (potassium < 1 && potassium > 0) potassium *= 1000; // Grams to mg

          if (calories == 0) {
            calories = (protein * 4) + (carbs * 4) + (fat * 9);
          }

          return {
            'calories': calories,
            'protein': protein,
            'carbs': carbs,
            'fat': fat,
            'vitaminA': vitA,
            'vitaminC': vitC,
            'vitaminD': vitD,
            'calcium': calcium,
            'iron': iron,
            'potassium': potassium,
          };
        }
      }
    } catch (e) {
      debugPrint("Open Food Facts API Error: $e");
    }
    return null;
  }

  Map<String, double> _generateMockNutrition(String foodName) {
    final query = foodName.toLowerCase();
    
    // Default fallback values
    double calories = 150.0;
    double protein = 5.0;
    double carbs = 20.0;
    double fat = 4.0;
    
    double vitA = 50.0; // mcg
    double vitC = 15.0; // mg
    double vitD = 1.2;  // mcg
    double calcium = 45.0; // mg
    double iron = 1.5;   // mg
    double potassium = 280.0; // mg

    if (query.contains('pizza')) {
      calories = 285.0; protein = 12.0; carbs = 33.0; fat = 10.0;
      vitA = 80.0; vitC = 2.4; vitD = 0.5; calcium = 200.0; iron = 2.5; potassium = 180.0;
    } else if (query.contains('chicken') || query.contains('breast') || query.contains('poultry')) {
      calories = 165.0; protein = 31.0; carbs = 0.0; fat = 3.6;
      vitA = 10.0; vitC = 0.0; vitD = 0.1; calcium = 15.0; iron = 1.0; potassium = 256.0;
    } else if (query.contains('salad') || query.contains('caesar')) {
      calories = 120.0; protein = 3.0; carbs = 8.0; fat = 9.0;
      vitA = 320.0; vitC = 28.0; vitD = 0.0; calcium = 80.0; iron = 1.2; potassium = 240.0;
    } else if (query.contains('apple') || query.contains('fruit')) {
      calories = 95.0; protein = 0.5; carbs = 25.0; fat = 0.3;
      vitA = 3.0; vitC = 8.4; vitD = 0.0; calcium = 6.0; iron = 0.2; potassium = 195.0;
    } else if (query.contains('burger') || query.contains('beef')) {
      calories = 354.0; protein = 20.0; carbs = 38.0; fat = 17.0;
      vitA = 45.0; vitC = 1.2; vitD = 0.8; calcium = 120.0; iron = 3.5; potassium = 310.0;
    } else if (query.contains('egg') || query.contains('omelet')) {
      calories = 143.0; protein = 12.6; carbs = 0.7; fat = 9.5;
      vitA = 160.0; vitC = 0.0; vitD = 2.0; calcium = 56.0; iron = 1.8; potassium = 138.0;
    } else if (query.contains('salmon') || query.contains('fish') || query.contains('tuna')) {
      calories = 208.0; protein = 22.0; carbs = 0.0; fat = 13.0;
      vitA = 40.0; vitC = 0.0; vitD = 12.0; calcium = 12.0; iron = 0.8; potassium = 363.0;
    } else if (query.contains('rice') || query.contains('grain')) {
      calories = 130.0; protein = 2.7; carbs = 28.0; fat = 0.3;
      vitA = 0.0; vitC = 0.0; vitD = 0.0; calcium = 10.0; iron = 1.2; potassium = 35.0;
    } else if (query.contains('shake') || query.contains('smoothie') || query.contains('protein powder')) {
      calories = 220.0; protein = 25.0; carbs = 15.0; fat = 3.0;
      vitA = 120.0; vitC = 12.0; vitD = 4.0; calcium = 300.0; iron = 2.0; potassium = 450.0;
    } else if (query.contains('oat') || query.contains('oatmeal') || query.contains('porridge')) {
      calories = 150.0; protein = 6.0; carbs = 27.0; fat = 2.5;
      vitA = 0.0; vitC = 0.0; vitD = 0.0; calcium = 30.0; iron = 1.8; potassium = 115.0;
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'vitaminA': vitA,
      'vitaminC': vitC,
      'vitaminD': vitD,
      'calcium': calcium,
      'iron': iron,
      'potassium': potassium,
    };
  }
}
