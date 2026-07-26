import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nutrition_result.dart';
import 'nutrition_api_service.dart';

class FoodScanService {
  final Dio _dio;
  final NutritionApiService _nutritionApiService;
  final bool _useMock;

  FoodScanService({
    required Dio dio,
    required NutritionApiService nutritionApiService,
    bool useMock = false,
  })  : _dio = dio,
        _nutritionApiService = nutritionApiService,
        _useMock = useMock;

  // ─── PHOTO SCAN (Gemini via Edge Function) ────────────────────────────────

  Future<NutritionResult> scanFoodImage(File imageFile) async {
    final isSimulated = imageFile.path.contains('simulated_food.jpg');

    if (_useMock || isSimulated) {
      debugPrint('FoodScanService: Using mock AI image analysis');
      await Future.delayed(const Duration(seconds: 2));

      final mockMeals = [
        {'name': 'Grilled Chicken Caesar Salad', 'grams': 350.0},
        {'name': 'Pepperoni Pizza Slice',         'grams': 220.0},
        {'name': 'Oatmeal with Blueberries',      'grams': 280.0},
        {'name': 'Baked Salmon with Brown Rice',  'grams': 400.0},
        {'name': 'Double Beef Cheeseburger',      'grams': 240.0},
        {'name': 'Scrambled Eggs & Avocado Toast','grams': 300.0},
      ];
      final sel = mockMeals[Random().nextInt(mockMeals.length)];
      final name = sel['name'] as String;
      final grams = sel['grams'] as double;
      final nutrition = await _nutritionApiService.fetchFoodNutrition(name);
      return _buildResult(name, grams, nutrition, 'mock');
    }

    try {
      // 1. Upload photo to Supabase Storage
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final bytes = await imageFile.readAsBytes();
      final fileName = 'scan_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage
          .from('scan-photos')
          .uploadBinary(fileName, bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));

      final imageUrl = supabase.storage.from('scan-photos').getPublicUrl(fileName);

      // 2. Call the scan-food Edge Function
      final response = await supabase.functions.invoke(
        'scan-food',
        body: {'image_url': imageUrl, 'user_id': userId},
      );

      final data = response.data as Map<String, dynamic>;

      if (data['status'] == 'limit_reached') {
        throw ScanLimitReachedException(
            'Daily AI scan limit reached (5/day). Try manual search.');
      }

      if (data['status'] == 'error') {
        throw Exception(data['message'] ?? 'Edge function error');
      }

      // 3. Build result from Edge Function response
      final name = data['food_name'] as String? ?? 'Scanned Meal';
      final grams = (data['portion_grams'] as num?)?.toDouble() ?? 100.0;

      return NutritionResult(
        foodName: name,
        portionEstimate: '${grams.round()}g (AI estimate)',
        portionGrams: grams,
        portionMultiplier: 1.0,
        calories: (data['calories'] as num?)?.toDouble() ?? 0,
        protein: (data['protein'] as num?)?.toDouble() ?? 0,
        carbs: (data['carbs'] as num?)?.toDouble() ?? 0,
        fat: (data['fat'] as num?)?.toDouble() ?? 0,
        vitaminA: (data['vitamin_a'] as num?)?.toDouble() ?? 0,
        vitaminC: (data['vitamin_c'] as num?)?.toDouble() ?? 0,
        vitaminD: (data['vitamin_d'] as num?)?.toDouble() ?? 0,
        calcium: (data['calcium'] as num?)?.toDouble() ?? 0,
        iron: (data['iron'] as num?)?.toDouble() ?? 0,
        potassium: (data['potassium'] as num?)?.toDouble() ?? 0,
        source: data['source'] as String? ?? 'gemini+usda',
        photoUrl: imageUrl,
      );
    } catch (e) {
      if (e is ScanLimitReachedException) rethrow;
      debugPrint('Photo scan error: $e — falling back to mock');
      // Graceful fallback so flow never breaks
      final nutrition = await _nutritionApiService.fetchFoodNutrition('mixed meal');
      return _buildResult('Scanned Meal', 300, nutrition, 'fallback');
    }
  }

  // ─── BARCODE SCAN (Open Food Facts) ──────────────────────────────────────

  Future<NutritionResult> scanBarcode(String barcode) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 800));
      final nutrition = await _nutritionApiService.fetchFoodNutrition('granola bar');
      return _buildResult('Demo Granola Bar', 45, nutrition, 'barcode');
    }

    try {
      final response = await _dio.get(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      if (response.statusCode == 200 && response.data != null) {
        final status = response.data['status'];
        if (status == 1) {
          final product = response.data['product'] as Map<String, dynamic>;
          final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
          final servingSize = _parseServingGrams(product['serving_size'] ?? '100g');
          final name = product['product_name'] as String? ??
              product['product_name_en'] as String? ??
              'Unknown Product';

          return NutritionResult(
            foodName: name,
            portionEstimate: 'Serving: ${servingSize.round()}g',
            portionGrams: servingSize,
            portionMultiplier: 1.0,
            calories: _num(nutriments, 'energy-kcal_serving') ??
                (_num(nutriments, 'energy-kcal_100g') ?? 0) * servingSize / 100,
            protein: (_num(nutriments, 'proteins_serving') ??
                    (_num(nutriments, 'proteins_100g') ?? 0) * servingSize / 100),
            carbs: (_num(nutriments, 'carbohydrates_serving') ??
                    (_num(nutriments, 'carbohydrates_100g') ?? 0) * servingSize / 100),
            fat: (_num(nutriments, 'fat_serving') ??
                    (_num(nutriments, 'fat_100g') ?? 0) * servingSize / 100),
            vitaminA: _micro(nutriments, 'vitamin-a'),
            vitaminC: _micro(nutriments, 'vitamin-c'),
            vitaminD: _micro(nutriments, 'vitamin-d'),
            calcium: _micro(nutriments, 'calcium'),
            iron: _micro(nutriments, 'iron'),
            potassium: _micro(nutriments, 'potassium'),
            source: 'barcode',
            photoUrl: product['image_url'] as String?,
          );
        }
      }
    } catch (e) {
      debugPrint('Barcode scan error: $e');
    }

    throw BarcodeNotFoundException(
        'Product not found for barcode $barcode. Try searching manually.');
  }

  // ─── MANUAL TEXT SEARCH ───────────────────────────────────────────────────

  Future<NutritionResult> searchFood(String query) async {
    final nutrition = await _nutritionApiService.fetchFoodNutrition(query);
    return _buildResult(query, 100, nutrition, 'search');
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  NutritionResult _buildResult(
      String name, double grams, Map<String, double> n, String source) {
    return NutritionResult(
      foodName: name,
      portionEstimate: '${grams.round()}g',
      portionGrams: grams,
      portionMultiplier: 1.0,
      calories: n['calories'] ?? 0,
      protein: n['protein'] ?? 0,
      carbs: n['carbs'] ?? 0,
      fat: n['fat'] ?? 0,
      vitaminA: n['vitaminA'] ?? 0,
      vitaminC: n['vitaminC'] ?? 0,
      vitaminD: n['vitaminD'] ?? 0,
      calcium: n['calcium'] ?? 0,
      iron: n['iron'] ?? 0,
      potassium: n['potassium'] ?? 0,
      source: source,
    );
  }

  double _parseServingGrams(String serving) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(serving);
    if (match != null) return double.tryParse(match.group(1)!) ?? 100.0;
    return 100.0;
  }

  double? _num(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) return null;
    return (v as num).toDouble();
  }

  double _micro(Map<String, dynamic> m, String key) {
    // Open Food Facts stores micros in grams — convert to mg/mcg sensibly
    double? val = _num(m, '${key}_100g');
    if (val == null) return 0;
    if (val < 0.1 && val > 0) val *= 1000; // g → mg
    return val;
  }
}

class ScanLimitReachedException implements Exception {
  final String message;
  ScanLimitReachedException(this.message);
  @override
  String toString() => message;
}

class BarcodeNotFoundException implements Exception {
  final String message;
  BarcodeNotFoundException(this.message);
  @override
  String toString() => message;
}
