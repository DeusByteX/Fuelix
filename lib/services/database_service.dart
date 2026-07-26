import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/meal_log.dart';
import '../models/workout.dart';

class DatabaseService {
  final Box _profileBox;
  final Box _mealBox;
  final Box _workoutBox;
  final Box _weightBox;
  
  bool _useSupabase = false;

  DatabaseService({
    required Box profileBox,
    required Box mealBox,
    required Box workoutBox,
    required Box weightBox,
  })  : _profileBox = profileBox,
        _mealBox = mealBox,
        _workoutBox = workoutBox,
        _weightBox = weightBox {
    _init();
  }

  void _init() {
    try {
      Supabase.instance.client;
      _useSupabase = true;
      debugPrint("DatabaseService initialized with Supabase Database");
    } catch (e) {
      _useSupabase = false;
      debugPrint("DatabaseService using Hive fallback: $e");
    }
  }

  bool get isSupabaseEnabled => _useSupabase;

  // --- MODEL TO POSTGRES SCHEMAS CONVERSIONS ---

  Map<String, dynamic> _profileToSupabase(UserProfile profile) {
    return {
      'id': profile.uid,
      'full_name': profile.name,
      'email': profile.email,
      'gender': profile.gender.toLowerCase(),
      'age': profile.age,
      'height_cm': profile.heightCm,
      'current_weight_kg': profile.weightKg,
      'target_weight_kg': profile.targetWeightKg,
      'primary_goals': profile.primaryGoals,
      'activity_level': profile.activityLevel.toLowerCase().replaceAll(' ', '_'),
      'dietary_preference': profile.dietaryPreference.toLowerCase().replaceAll(' ', '_'),
      'workout_days_per_week': profile.workoutDaysPerWeek,
      'allergies': profile.allergies,
      'units': profile.isMetric ? 'metric' : 'imperial',
      'daily_calorie_target': profile.dailyCalorieTarget,
      'daily_protein_target_g': profile.dailyProteinTarget,
      'daily_carbs_target_g': profile.dailyCarbsTarget,
      'daily_fat_target_g': profile.dailyFatTarget,
      'onboarding_completed': profile.isOnboarded,
      'theme_preference': profile.themePreference,
      'diet_strictness': profile.dietStrictness,
      'is_gym_active': profile.isGymActive,
    };
  }

  UserProfile _supabaseToProfile(Map<String, dynamic> map) {
    final String rawGender = map['gender'] ?? 'Male';
    final String gender = rawGender.substring(0, 1).toUpperCase() + rawGender.substring(1); 
    
    final rawActivity = map['activity_level'] ?? 'moderate';
    final String activity = rawActivity.replaceAll('_', ' ').split(' ').map((w) => w.substring(0, 1).toUpperCase() + w.substring(1)).join(' ');

    final rawPreference = map['dietary_preference'] ?? 'none';
    final String preference = rawPreference == 'none' || rawPreference == 'no_restriction'
        ? 'No restriction' 
        : (rawPreference.replaceAll('_', ' ').split(' ').map((w) => w.substring(0, 1).toUpperCase() + w.substring(1)).join(' '));

    return UserProfile(
      uid: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['full_name'] ?? 'User',
      gender: gender,
      age: (map['age'] as num?)?.toInt() ?? 25,
      heightCm: (map['height_cm'] as num?)?.toDouble() ?? 170.0,
      weightKg: (map['current_weight_kg'] as num?)?.toDouble() ?? 70.0,
      targetWeightKg: (map['target_weight_kg'] as num?)?.toDouble() ?? 70.0,
      primaryGoals: List<String>.from(map['primary_goals'] ?? ['Maintain']),
      activityLevel: activity,
      dietaryPreference: preference,
      workoutDaysPerWeek: (map['workout_days_per_week'] as num?)?.toInt() ?? 3,
      allergies: List<String>.from(map['allergies'] ?? []),
      isMetric: (map['units'] ?? 'metric') == 'metric',
      isOnboarded: map['onboarding_completed'] ?? false,
      themePreference: map['theme_preference'] ?? 'dark',
      dietStrictness: map['diet_strictness'] ?? 'Moderate',
      isGymActive: map['is_gym_active'] ?? false,
      dailyCalorieTarget: (map['daily_calorie_target'] as num?)?.toInt(),
      dailyProteinTarget: (map['daily_protein_target_g'] as num?)?.toInt(),
      dailyCarbsTarget: (map['daily_carbs_target_g'] as num?)?.toInt(),
      dailyFatTarget: (map['daily_fat_target_g'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> _mealToSupabase(MealLog meal) {
    return {
      'id': meal.id,
      'user_id': meal.userId,
      'food_name': meal.name,
      'meal_type': meal.mealCategory.toLowerCase(),
      'entry_method': 'manual',
      'portion_grams': meal.portionSizeMultiplier * 100.0, 
      'calories': meal.calories.toDouble(),
      'protein': meal.protein.toDouble(),
      'carbs': meal.carbs.toDouble(),
      'fat': meal.fat.toDouble(),
      'vitamin_a': meal.vitaminA.toDouble(),
      'vitamin_c': meal.vitaminC.toDouble(),
      'vitamin_d': meal.vitaminD.toDouble(),
      'iron': meal.iron.toDouble(),
      'calcium': meal.calcium.toDouble(),
      'potassium': meal.potassium.toDouble(),
      'photo_url': null,
      'logged_at': meal.date.toIso8601String(),
    };
  }

  MealLog _supabaseToMeal(Map<String, dynamic> map) {
    final String rawType = map['meal_type'] ?? 'breakfast';
    final String category = rawType.substring(0, 1).toUpperCase() + rawType.substring(1);
    
    final double portionGrams = (map['portion_grams'] as num?)?.toDouble() ?? 100.0;
    final double multiplier = portionGrams / 100.0;

    return MealLog(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      date: DateTime.tryParse(map['logged_at'] ?? '') ?? DateTime.now(),
      name: map['food_name'] ?? 'Food',
      mealCategory: category,
      baseCalories: ((map['calories'] as num?)?.toDouble() ?? 0.0) / (multiplier > 0 ? multiplier : 1.0),
      baseProtein: ((map['protein'] as num?)?.toDouble() ?? 0.0) / (multiplier > 0 ? multiplier : 1.0),
      baseCarbs: ((map['carbs'] as num?)?.toDouble() ?? 0.0) / (multiplier > 0 ? multiplier : 1.0),
      baseFat: ((map['fat'] as num?)?.toDouble() ?? 0.0) / (multiplier > 0 ? multiplier : 1.0),
      baseVitaminA: ((map['vitamin_a'] as num?)?.toDouble() ?? 0.0) / (multiplier > 0 ? multiplier : 1.0),
      baseVitaminC: ((map['vitamin_c'] as num?)?.toDouble() ?? 0.0) / (multiplier > 0 ? multiplier : 1.0),
      baseVitaminD: ((map['vitamin_d'] as num?)?.toDouble() ?? 0.0) / (multiplier > 0 ? multiplier : 1.0),
      baseIron: ((map['iron'] as num?)?.toDouble() ?? 0.0) / (multiplier > 0 ? multiplier : 1.0),
      baseCalcium: ((map['calcium'] as num?)?.toDouble() ?? 0.0) / (multiplier > 0 ? multiplier : 1.0),
      basePotassium: ((map['potassium'] as num?)?.toDouble() ?? 0.0) / (multiplier > 0 ? multiplier : 1.0),
      portionSizeMultiplier: multiplier,
    );
  }

  Map<String, dynamic> _workoutToSupabase(WorkoutSession session) {
    return {
      'id': session.id,
      'user_id': session.userId,
      'completed_at': session.startTime.toIso8601String(),
      'duration_minutes': 45, 
      'logged_exercises': session.exercises.map((e) => e.toMap()).toList(),
    };
  }

  WorkoutSession _supabaseToWorkout(Map<String, dynamic> map) {
    final List exercisesRaw = map['logged_exercises'] as List? ?? [];
    final List<Exercise> exercises = exercisesRaw.map((x) => Exercise.fromMap(Map<String, dynamic>.from(x as Map))).toList();

    return WorkoutSession(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      name: 'Completed Workout',
      startTime: DateTime.tryParse(map['completed_at'] ?? '') ?? DateTime.now(),
      exercises: exercises,
      isCompleted: true,
    );
  }

  // --- USER PROFILE METHODS ---

  Future<void> saveUserProfile(UserProfile profile) async {
    await _profileBox.put(profile.uid, profile.toMap());

    if (_useSupabase) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .upsert(_profileToSupabase(profile));
      } catch (e) {
        debugPrint("Error saving profile to Supabase: $e");
      }
    }
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    if (_useSupabase) {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', uid)
            .maybeSingle();
            
        if (data != null) {
          final profile = _supabaseToProfile(data);
          await _profileBox.put(uid, profile.toMap());
          return profile;
        }
      } catch (e) {
        debugPrint("Error fetching profile from Supabase: $e");
      }
    }

    final localData = _profileBox.get(uid);
    if (localData != null) {
      return UserProfile.fromMap(Map<String, dynamic>.from(localData as Map));
    }
    return null;
  }

  // --- MEAL LOG METHODS ---

  Future<void> saveMealLog(MealLog log) async {
    await _mealBox.put(log.id, log.toMap());

    if (_useSupabase) {
      try {
        await Supabase.instance.client
            .from('meal_logs')
            .upsert(_mealToSupabase(log));
      } catch (e) {
        debugPrint("Error saving meal log to Supabase: $e");
      }
    }
  }

  Future<void> deleteMealLog(String logId) async {
    await _mealBox.delete(logId);

    if (_useSupabase) {
      try {
        await Supabase.instance.client
            .from('meal_logs')
            .delete()
            .eq('id', logId);
      } catch (e) {
        debugPrint("Error deleting meal log from Supabase: $e");
      }
    }
  }

  Future<List<MealLog>> getMealLogs(String uid, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    if (_useSupabase) {
      try {
        final List data = await Supabase.instance.client
            .from('meal_logs')
            .select()
            .eq('user_id', uid)
            .gte('logged_at', startOfDay.toIso8601String())
            .lte('logged_at', endOfDay.toIso8601String());
        
        final list = data.map((item) => _supabaseToMeal(Map<String, dynamic>.from(item))).toList();
        for (var meal in list) {
          await _mealBox.put(meal.id, meal.toMap());
        }
        return list;
      } catch (e) {
        debugPrint("Error fetching meals from Supabase: $e");
      }
    }

    final allLocal = _mealBox.values.map((x) => MealLog.fromMap(Map<String, dynamic>.from(x as Map))).toList();
    return allLocal.where((meal) {
      return meal.userId == uid &&
          meal.date.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
          meal.date.isBefore(endOfDay.add(const Duration(seconds: 1)));
    }).toList();
  }

  Future<List<MealLog>> getMealLogsForRange(String uid, int days) async {
    final thresholdDate = DateTime.now().subtract(Duration(days: days));

    if (_useSupabase) {
      try {
        final List data = await Supabase.instance.client
            .from('meal_logs')
            .select()
            .eq('user_id', uid)
            .gte('logged_at', thresholdDate.toIso8601String());
        
        return data.map((item) => _supabaseToMeal(Map<String, dynamic>.from(item))).toList();
      } catch (e) {
        debugPrint("Error fetching meals range from Supabase: $e");
      }
    }

    final allLocal = _mealBox.values.map((x) => MealLog.fromMap(Map<String, dynamic>.from(x as Map))).toList();
    return allLocal.where((meal) {
      return meal.userId == uid && meal.date.isAfter(thresholdDate);
    }).toList();
  }

  // --- WORKOUT SESSION METHODS ---

  Future<void> saveWorkoutSession(WorkoutSession session) async {
    await _workoutBox.put(session.id, session.toMap());

    if (_useSupabase) {
      try {
        await Supabase.instance.client
            .from('workout_logs')
            .upsert(_workoutToSupabase(session));
      } catch (e) {
        debugPrint("Error saving workout session to Supabase: $e");
      }
    }
  }

  Future<List<WorkoutSession>> getWorkoutSessions(String uid) async {
    if (_useSupabase) {
      try {
        final List data = await Supabase.instance.client
            .from('workout_logs')
            .select()
            .eq('user_id', uid)
            .order('completed_at', ascending: false);
        
        final list = data.map((item) => _supabaseToWorkout(Map<String, dynamic>.from(item))).toList();
        for (var sess in list) {
          await _workoutBox.put(sess.id, sess.toMap());
        }
        return list;
      } catch (e) {
        debugPrint("Error fetching workouts from Supabase: $e");
      }
    }

    final allLocal = _workoutBox.values
        .map((x) => WorkoutSession.fromMap(Map<String, dynamic>.from(x as Map)))
        .toList();
    
    final filtered = allLocal.where((sess) => sess.userId == uid).toList();
    filtered.sort((a, b) => b.startTime.compareTo(a.startTime));
    return filtered;
  }

  // --- BURNED ACTIVITY METHODS ---
  Future<void> saveBurnedActivity(BurnedActivity activity) async {
    // Use 'burned_' prefix to avoid key collisions with WorkoutSession entries in same box
    await _workoutBox.put('burned_${activity.id}', activity.toMap());

    if (_useSupabase) {
      try {
        await Supabase.instance.client
            .from('burned_activities')
            .upsert({
          'id': activity.id,
          'user_id': activity.userId,
          'activity_name': activity.name,
          'duration_minutes': activity.durationMinutes,
          'intensity': activity.intensity.toLowerCase(),
          'carries_extra_load': activity.carriesExtraLoad,
          'calories_burned': activity.caloriesBurned,
          'logged_at': activity.timestamp.toIso8601String(),
        });
      } catch (e) {
        debugPrint("Error saving burned activity to Supabase: $e");
      }
    }
  }

  Future<void> deleteBurnedActivity(String activityId) async {
    await _workoutBox.delete('burned_$activityId');

    if (_useSupabase) {
      try {
        await Supabase.instance.client
            .from('burned_activities')
            .delete()
            .eq('id', activityId);
      } catch (e) {
        debugPrint("Error deleting burned activity from Supabase: $e");
      }
    }
  }

  Future<List<BurnedActivity>> getBurnedActivities(String uid) async {
    if (_useSupabase) {
      try {
        final List data = await Supabase.instance.client
            .from('burned_activities')
            .select()
            .eq('user_id', uid)
            .order('logged_at', ascending: false);

        final list = data.map((item) {
          final m = Map<String, dynamic>.from(item);
          final act = BurnedActivity(
            id: m['id'] ?? '',
            userId: m['user_id'] ?? '',
            name: m['activity_name'] ?? '',
            durationMinutes: (m['duration_minutes'] as num?)?.toDouble() ?? 0.0,
            intensity: _capitalize(m['intensity'] ?? 'moderate'),
            carriesExtraLoad: m['carries_extra_load'] ?? false,
            caloriesBurned: (m['calories_burned'] as num?)?.toInt() ?? 0,
            timestamp: DateTime.tryParse(m['logged_at'] ?? '') ?? DateTime.now(),
          );
          // Cache locally with prefix
          _workoutBox.put('burned_${act.id}', act.toMap());
          return act;
        }).toList();

        return list;
      } catch (e) {
        debugPrint("Error fetching burned activities from Supabase: $e");
      }
    }

    // Fallback: read from Hive using 'burned_' prefix keys only
    final activities = <BurnedActivity>[];
    for (final key in _workoutBox.keys) {
      if (key.toString().startsWith('burned_')) {
        final raw = _workoutBox.get(key);
        if (raw != null) {
          final map = Map<String, dynamic>.from(raw as Map);
          if (map['userId'] == uid) {
            activities.add(BurnedActivity.fromMap(map));
          }
        }
      }
    }
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  // --- WEIGHT LOG METHODS ---

  Future<void> saveWeightLog(String uid, double weightKg, DateTime date) async {
    final id = '${uid}_weight_${date.millisecondsSinceEpoch}';
    final rawData = {
      'id': id,
      'userId': uid,
      'weightKg': weightKg,
      'date': date.toIso8601String(),
    };

    await _weightBox.put(id, rawData);

    if (_useSupabase) {
      try {
        final supabaseData = {
          'user_id': uid,
          'weight_kg': weightKg,
          'logged_at': date.toIso8601String(),
        };
        await Supabase.instance.client
            .from('weight_logs')
            .insert(supabaseData);
      } catch (e) {
        debugPrint("Error saving weight log to Supabase: $e");
      }
    }
  }

  Future<List<Map<String, dynamic>>> getWeightLogs(String uid) async {
    if (_useSupabase) {
      try {
        final List data = await Supabase.instance.client
            .from('weight_logs')
            .select()
            .eq('user_id', uid)
            .order('logged_at', ascending: true);
        
        final list = data.map((item) {
          final mapped = Map<String, dynamic>.from(item);
          return {
            'id': mapped['id'] ?? '',
            'userId': mapped['user_id'] ?? '',
            'weightKg': (mapped['weight_kg'] as num?)?.toDouble() ?? 0.0,
            'date': mapped['logged_at'] ?? '',
          };
        }).toList();
        
        for (var item in list) {
          await _weightBox.put(item['id'], item);
        }
        return list;
      } catch (e) {
        debugPrint("Error fetching weight logs from Supabase: $e");
      }
    }

    final allLocal = _weightBox.values
        .map((x) => Map<String, dynamic>.from(x as Map))
        .where((item) => item['userId'] == uid)
        .toList();
    
    allLocal.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    return allLocal;
  }
}
