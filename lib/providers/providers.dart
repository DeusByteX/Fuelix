import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

import '../models/user_profile.dart';
import '../models/meal_log.dart';
import '../models/workout.dart';
import '../models/nutrition_result.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/nutrition_api_service.dart';
import '../services/food_scan_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_client;

// --- SERVICE PROVIDERS ---

final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

final authBoxProvider = Provider<Box>((ref) {
  return Hive.box('fuelix_auth');
});

final profileBoxProvider = Provider<Box>((ref) {
  return Hive.box('fuelix_profiles');
});

final mealBoxProvider = Provider<Box>((ref) {
  return Hive.box('fuelix_meal_logs');
});

final workoutBoxProvider = Provider<Box>((ref) {
  return Hive.box('fuelix_workouts');
});

final weightBoxProvider = Provider<Box>((ref) {
  return Hive.box('fuelix_weights');
});

final authServiceProvider = Provider<AuthService>((ref) {
  final box = ref.read(authBoxProvider);
  return AuthService(box);
});

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService(
    profileBox: ref.read(profileBoxProvider),
    mealBox: ref.read(mealBoxProvider),
    workoutBox: ref.read(workoutBoxProvider),
    weightBox: ref.read(weightBoxProvider),
  );
});

final nutritionApiServiceProvider = Provider<NutritionApiService>((ref) {
  final dio = ref.read(dioProvider);
  final usdaKey = dotenv.env['USDA_API_KEY'] ?? 'DEMO_KEY';
  final useMock = dotenv.env['USE_MOCK_SERVICES']?.toLowerCase() == 'true';
  return NutritionApiService(dio: dio, usdaApiKey: usdaKey, useMock: useMock);
});

final foodScanServiceProvider = Provider<FoodScanService>((ref) {
  final dio = ref.read(dioProvider);
  final nutritionService = ref.read(nutritionApiServiceProvider);
  final useMock = dotenv.env['USE_MOCK_SERVICES']?.toLowerCase() == 'true';
  return FoodScanService(
    dio: dio,
    nutritionApiService: nutritionService,
    useMock: useMock,
  );
});

// --- AUTHENTICATION STATE PROVIDER ---

final authStateProvider = StreamProvider<FuelixUser?>((ref) {
  return ref.read(authServiceProvider).authStateChanges;
});

// --- USER PROFILE STATE MANAGEMENT ---

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile?>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  final notifier = UserProfileNotifier(dbService);
  
  // Listen to auth changes to clear the profile on logout (avoiding parallel load race conditions)
  ref.listen<AsyncValue<FuelixUser?>>(authStateProvider, (previous, next) {
    if (next.value == null) {
      notifier.clearProfile();
    }
  });

  return notifier;
});

class UserProfileNotifier extends StateNotifier<UserProfile?> {
  final DatabaseService _dbService;

  UserProfileNotifier(this._dbService) : super(null);

  Future<void> loadProfile(String uid, String email, String name) async {
    final profile = await _dbService.getUserProfile(uid);
    if (!mounted) return;
    if (profile != null) {
      // Sync back to Supabase if local state is onboarded but server is incomplete
      if (state != null && state!.isOnboarded && !profile.isOnboarded) {
        _dbService.saveUserProfile(state!);
        return;
      }
      state = profile;
    } else {
      // Only fall back to default profile if there is no cached state
      if (state == null) {
        state = UserProfile(
          uid: uid,
          email: email,
          name: name,
          gender: 'Male',
          age: 25,
          heightCm: 175,
          weightKg: 70,
          targetWeightKg: 70,
          primaryGoals: const ['Maintain'],
          activityLevel: 'Moderate',
          dietaryPreference: 'No restriction',
          workoutDaysPerWeek: 3,
          allergies: [],
        );
      }
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _dbService.saveUserProfile(profile);
    if (!mounted) return;
    state = profile;
  }

  Future<void> updateWeight(double newWeightKg) async {
    if (state != null) {
      final updated = state!.copyWith(weightKg: newWeightKg);
      await saveProfile(updated);
      await _dbService.saveWeightLog(state!.uid, newWeightKg, DateTime.now());
    }
  }

  void clearProfile() {
    state = null;
  }
}

// --- DIET & MEAL LOGS STATE MANAGEMENT ---

class DietState {
  final DateTime selectedDate;
  final List<MealLog> mealLogs;
  final bool isLoading;

  DietState({
    required this.selectedDate,
    required this.mealLogs,
    this.isLoading = false,
  });

  // Derived macro targets vs consumed
  double get totalCalories => mealLogs.fold(0.0, (sum, item) => sum + item.calories);
  double get totalProtein => mealLogs.fold(0.0, (sum, item) => sum + item.protein);
  double get totalCarbs => mealLogs.fold(0.0, (sum, item) => sum + item.carbs);
  double get totalFat => mealLogs.fold(0.0, (sum, item) => sum + item.fat);

  double get totalVitaminA => mealLogs.fold(0.0, (sum, item) => sum + item.vitaminA);
  double get totalVitaminC => mealLogs.fold(0.0, (sum, item) => sum + item.vitaminC);
  double get totalVitaminD => mealLogs.fold(0.0, (sum, item) => sum + item.vitaminD);
  double get totalCalcium => mealLogs.fold(0.0, (sum, item) => sum + item.calcium);
  double get totalIron => mealLogs.fold(0.0, (sum, item) => sum + item.iron);
  double get totalPotassium => mealLogs.fold(0.0, (sum, item) => sum + item.potassium);

  DietState copyWith({
    DateTime? selectedDate,
    List<MealLog>? mealLogs,
    bool? isLoading,
  }) {
    return DietState(
      selectedDate: selectedDate ?? this.selectedDate,
      mealLogs: mealLogs ?? this.mealLogs,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final dietProvider = StateNotifierProvider<DietNotifier, DietState>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  final notifier = DietNotifier(dbService);

  // React to profile load/changes so data reloads when userId becomes available
  ref.listen<UserProfile?>(userProfileProvider, (previous, next) {
    if (next?.uid != previous?.uid) {
      notifier.onUserChanged(next?.uid);
    }
  }, fireImmediately: true);

  return notifier;
});

class DietNotifier extends StateNotifier<DietState> {
  final DatabaseService _dbService;
  String? _userId;

  DietNotifier(this._dbService)
      : super(DietState(selectedDate: DateTime.now(), mealLogs: []));

  void onUserChanged(String? uid) {
    _userId = uid;
    if (uid != null) {
      loadMealsForDate(state.selectedDate);
    } else {
      // Clear meals on logout
      state = DietState(selectedDate: DateTime.now(), mealLogs: []);
    }
  }

  Future<void> changeDate(DateTime date) async {
    state = state.copyWith(selectedDate: date);
    await loadMealsForDate(date);
  }

  Future<void> loadMealsForDate(DateTime date) async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true);
    final meals = await _dbService.getMealLogs(_userId!, date);
    state = state.copyWith(mealLogs: meals, isLoading: false);
  }

  Future<void> addMeal({
    required String name,
    required String category,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double vitA = 0.0,
    double vitC = 0.0,
    double vitD = 0.0,
    double calcium = 0.0,
    double iron = 0.0,
    double potassium = 0.0,
    double portionMultiplier = 1.0,
  }) async {
    if (_userId == null) return;
    
    final meal = MealLog(
      id: Uuid().v4(),
      userId: _userId!,
      date: state.selectedDate,
      name: name,
      mealCategory: category,
      baseCalories: calories,
      baseProtein: protein,
      baseCarbs: carbs,
      baseFat: fat,
      baseVitaminA: vitA,
      baseVitaminC: vitC,
      baseVitaminD: vitD,
      baseCalcium: calcium,
      baseIron: iron,
      basePotassium: potassium,
      portionSizeMultiplier: portionMultiplier,
    );

    await _dbService.saveMealLog(meal);
    state = state.copyWith(mealLogs: [...state.mealLogs, meal]);
  }

  Future<void> updateMeal(MealLog updatedMeal) async {
    await _dbService.saveMealLog(updatedMeal);
    state = state.copyWith(
      mealLogs: state.mealLogs.map((m) => m.id == updatedMeal.id ? updatedMeal : m).toList(),
    );
  }

  Future<void> deleteMeal(String mealId) async {
    await _dbService.deleteMealLog(mealId);
    state = state.copyWith(
      mealLogs: state.mealLogs.where((m) => m.id != mealId).toList(),
    );
  }
}

// --- WORKOUT STATE & HISTORY MANAGEMENT ---

class WorkoutState {
  final List<WorkoutSession> completedSessions;
  final List<BurnedActivity> loggedActivities;
  final WorkoutSession? activeSession;
  final bool isLoading;

  WorkoutState({
    required this.completedSessions,
    required this.loggedActivities,
    this.activeSession,
    this.isLoading = false,
  });

  WorkoutState copyWith({
    List<WorkoutSession>? completedSessions,
    List<BurnedActivity>? loggedActivities,
    WorkoutSession? activeSession,
    bool? isLoading,
    bool clearActiveSession = false,
  }) {
    return WorkoutState(
      completedSessions: completedSessions ?? this.completedSessions,
      loggedActivities: loggedActivities ?? this.loggedActivities,
      activeSession: clearActiveSession ? null : (activeSession ?? this.activeSession),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final workoutProvider = StateNotifierProvider<WorkoutNotifier, WorkoutState>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  final notifier = WorkoutNotifier(dbService);

  // React to profile load/changes so data reloads when userId becomes available
  ref.listen<UserProfile?>(userProfileProvider, (previous, next) {
    if (next?.uid != previous?.uid) {
      notifier.onUserChanged(next?.uid);
    }
  }, fireImmediately: true);

  return notifier;
});

class WorkoutNotifier extends StateNotifier<WorkoutState> {
  final DatabaseService _dbService;
  String? _userId;

  WorkoutNotifier(this._dbService)
      : super(WorkoutState(completedSessions: [], loggedActivities: []));

  void onUserChanged(String? uid) {
    _userId = uid;
    if (uid != null) {
      loadSessions();
    } else {
      // Clear workout data on logout
      state = WorkoutState(completedSessions: [], loggedActivities: []);
    }
  }

  Future<void> loadSessions() async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true);
    final sessions = await _dbService.getWorkoutSessions(_userId!);
    final activities = await _dbService.getBurnedActivities(_userId!);
    state = state.copyWith(
      completedSessions: sessions,
      loggedActivities: activities,
      isLoading: false,
    );
  }

  void startWorkout(String workoutName, List<Exercise> templateExercises) {
    if (_userId == null) return;
    final newSession = WorkoutSession(
      id: Uuid().v4(),
      userId: _userId!,
      name: workoutName,
      startTime: DateTime.now(),
      exercises: templateExercises,
      isCompleted: false,
    );
    state = state.copyWith(activeSession: newSession);
  }

  void updateActiveWorkout(WorkoutSession updatedSession) {
    state = state.copyWith(activeSession: updatedSession);
  }

  Future<void> completeWorkout() async {
    if (state.activeSession == null) return;
    final completed = state.activeSession!.copyWith(
      endTime: DateTime.now(),
      isCompleted: true,
    );

    await _dbService.saveWorkoutSession(completed);
    state = state.copyWith(
      completedSessions: [completed, ...state.completedSessions],
      clearActiveSession: true,
    );
  }

  void cancelActiveWorkout() {
    state = state.copyWith(clearActiveSession: true);
  }

  Future<void> logActivity({
    required String name,
    required double durationMinutes,
    required String intensity,
    required bool carriesExtraLoad,
    required double userWeightKg,
  }) async {
    if (_userId == null) return;

    double met = 6.0;
    final lowerName = name.toLowerCase();
    final lowerIntensity = intensity.toLowerCase();

    if (lowerName.contains('run')) {
      met = lowerIntensity == 'low' ? 7.0 : (lowerIntensity == 'extreme' ? 12.3 : 9.8);
    } else if (lowerName.contains('cycl') || lowerName.contains('bike')) {
      met = lowerIntensity == 'low' ? 4.0 : (lowerIntensity == 'extreme' ? 12.0 : 7.5);
    } else if (lowerName.contains('swim')) {
      met = lowerIntensity == 'low' ? 5.8 : (lowerIntensity == 'extreme' ? 10.0 : 8.3);
    } else if (lowerName.contains('weight') || lowerName.contains('lift') || lowerName.contains('strength')) {
      met = lowerIntensity == 'low' ? 3.0 : (lowerIntensity == 'extreme' ? 7.5 : 5.0);
    } else if (lowerName.contains('hiit') || lowerName.contains('cardio')) {
      met = lowerIntensity == 'low' ? 6.0 : (lowerIntensity == 'extreme' ? 11.0 : 8.0);
    } else if (lowerName.contains('yoga') || lowerName.contains('stretch')) {
      met = lowerIntensity == 'low' ? 2.0 : (lowerIntensity == 'extreme' ? 4.5 : 3.0);
    } else {
      met = lowerIntensity == 'low' ? 3.5 : (lowerIntensity == 'extreme' ? 8.0 : 5.5);
    }

    double calories = (durationMinutes / 60.0) * met * userWeightKg;

    if (carriesExtraLoad) {
      calories *= 1.15;
    }

    final activity = BurnedActivity(
      id: Uuid().v4(),
      userId: _userId!,
      name: name,
      durationMinutes: durationMinutes,
      intensity: intensity,
      carriesExtraLoad: carriesExtraLoad,
      caloriesBurned: calories.round(),
      timestamp: DateTime.now(),
    );

    await _dbService.saveBurnedActivity(activity);
    state = state.copyWith(
      loggedActivities: [activity, ...state.loggedActivities],
    );
  }

  Future<void> deleteActivity(String activityId) async {
    await _dbService.deleteBurnedActivity(activityId);
    state = state.copyWith(
      loggedActivities: state.loggedActivities.where((a) => a.id != activityId).toList(),
    );
  }
}

// --- WEIGHT PROGRESS STATE MANAGEMENT ---

final weightLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = ref.watch(userProfileProvider);
  if (profile == null) return [];
  return ref.read(databaseServiceProvider).getWeightLogs(profile.uid);
});

// --- THEME STATE MANAGEMENT ---

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Box _authBox;

  ThemeModeNotifier(this._authBox) : super(ThemeMode.system) {
    _loadTheme();
  }

  void _loadTheme() {
    final saved = _authBox.get('theme_preference', defaultValue: 'system') as String;
    state = _stringToThemeMode(saved);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final val = _themeModeToString(mode);
    await _authBox.put('theme_preference', val);
    
    // Attempt live sync to Supabase if authenticated
    try {
      // Import/use Supabase client directly
      final user = supabase_client.Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await supabase_client.Supabase.instance.client
            .from('profiles')
            .update({'theme_preference': val})
            .eq('id', user.id);
      }
    } catch (e) {
      debugPrint("Warning: Could not sync theme preference: $e");
    }
  }

  ThemeMode _stringToThemeMode(String val) {
    switch (val) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final authBox = ref.watch(authBoxProvider);
  return ThemeModeNotifier(authBox);
});
