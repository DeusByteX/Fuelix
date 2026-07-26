import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/workout.dart';
import '../../models/user_profile.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import 'workout_detail_screen.dart';

class WorkoutTab extends ConsumerWidget {
  const WorkoutTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(userProfileProvider);
    final dietState = ref.watch(dietProvider);
    final workoutState = ref.watch(workoutProvider);

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final targetCalories = profile.dailyCalorieTarget;
    final consumedCalories = dietState.totalCalories;
    final remainingCalories = targetCalories - consumedCalories;

    // Generated Goal-Specific Workout Template
    final workoutName = _getWorkoutName(profile.primaryGoals);
    final exercises = _getExercisesForGoal(profile.primaryGoals, profile.isMetric);

    // Calculate completed workouts count for the current week
    final completedThisWeek = _getCompletedThisWeekCount(workoutState.completedSessions);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary,
                        ),
                      ),
                      Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : FuelixTheme.textDarkPrimary,
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: FuelixTheme.accentOrange.withOpacity(0.1),
                    child: Text(
                      profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: FuelixTheme.accentOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Nutrition Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? FuelixTheme.darkCard : Colors.white,
                  borderRadius: FuelixTheme.cardRadius,
                  boxShadow: FuelixTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Nutrition Overview',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Donut Chart
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: Stack(
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 46,
                                  startDegreeOffset: -90,
                                  sections: _getPieSections(dietState),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      remainingCalories.round().abs().toString(),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: remainingCalories >= 0 ? FuelixTheme.accentOrange : Colors.greenAccent,
                                      ),
                                    ),
                                    Text(
                                      remainingCalories >= 0 ? 'kcal left' : 'kcal over',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Summary List
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMacroIndicator(
                                'Carbs',
                                dietState.totalCarbs.round(),
                                profile.dailyCarbsTarget,
                                FuelixTheme.accentOrange,
                                isDark,
                              ),
                              const SizedBox(height: 12),
                              _buildMacroIndicator(
                                'Protein',
                                dietState.totalProtein.round(),
                                profile.dailyProteinTarget,
                                FuelixTheme.accentLime,
                                isDark,
                              ),
                              const SizedBox(height: 12),
                              _buildMacroIndicator(
                                'Fat',
                                dietState.totalFat.round(),
                                profile.dailyFatTarget,
                                const Color(0xFF00C2FF),
                                isDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Weekly Progress Streak
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? FuelixTheme.darkCard : Colors.white,
                  borderRadius: FuelixTheme.cardRadius,
                  boxShadow: FuelixTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Weekly Activity Streak',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$completedThisWeek / ${profile.workoutDaysPerWeek} days',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: FuelixTheme.accentOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        final weekDays = _getWeekDays();
                        final dayDate = weekDays[index];
                        final isCompleted = _isWorkoutCompletedOnDate(workoutState.completedSessions, dayDate);
                        final isToday = DateUtils.isSameDay(dayDate, DateTime.now());
                        
                        return Column(
                          children: [
                            Text(
                              DateFormat('E').format(dayDate)[0], // M, T, W, T...
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isToday ? FuelixTheme.accentOrange : (isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? FuelixTheme.accentOrange
                                    : (isToday 
                                        ? FuelixTheme.accentOrange.withOpacity(0.15) 
                                        : (isDark ? FuelixTheme.darkBg : Colors.grey[100])),
                                border: Border.all(
                                  color: isToday ? FuelixTheme.accentOrange : Colors.transparent,
                                  width: 1.5,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  isCompleted ? Icons.check : Icons.fitness_center_rounded,
                                  size: 16,
                                  color: isCompleted
                                      ? Colors.white
                                      : (isToday 
                                          ? FuelixTheme.accentOrange 
                                          : (isDark ? Colors.white30 : Colors.black26)),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildBurnAndWeightLossCard(workoutState, profile, context, ref, isDark),
              const SizedBox(height: 24),

              // Today's Workout Card
              const Text(
                'Today\'s Program',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                        ? [const Color(0xFF231411), FuelixTheme.darkCard]
                        : [const Color(0xFFFFF0EC), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: FuelixTheme.cardRadius,
                  border: Border.all(color: FuelixTheme.accentOrange.withOpacity(0.1)),
                  boxShadow: FuelixTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: FuelixTheme.accentOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            profile.primaryGoals.join(' & '),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: FuelixTheme.accentOrange,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 16, color: FuelixTheme.accentOrange),
                            const SizedBox(width: 4),
                            Text(
                              '${exercises.length * 8} mins',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      workoutName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${exercises.length} Exercises targeting your body dynamics.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Text('Start Workout'),
                        onPressed: () {
                          // Trigger start workout in provider
                          ref.read(workoutProvider.notifier).startWorkout(workoutName, exercises);
                          // Route to details
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const WorkoutDetailScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- MACRO PROGRESS LINE WIDGET ---
  Widget _buildMacroIndicator(String label, int value, int target, Color color, bool isDark) {
    final double pct = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              '$value / $target g',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: isDark ? const Color(0xFF2C2D31) : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // --- DONUT SECTIONS GENERATOR ---
  List<PieChartSectionData> _getPieSections(DietState state) {
    final carbGrams = state.totalCarbs;
    final protGrams = state.totalProtein;
    final fatGrams = state.totalFat;
    final totalGrams = carbGrams + protGrams + fatGrams;

    if (totalGrams == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.withOpacity(0.2),
          value: 100,
          showTitle: false,
          radius: 12,
        ),
      ];
    }

    return [
      PieChartSectionData(
        color: FuelixTheme.accentOrange,
        value: carbGrams,
        showTitle: false,
        radius: 12,
      ),
      PieChartSectionData(
        color: FuelixTheme.accentLime,
        value: protGrams,
        showTitle: false,
        radius: 12,
      ),
      PieChartSectionData(
        color: const Color(0xFF00C2FF),
        value: fatGrams,
        showTitle: false,
        radius: 12,
      ),
    ];
  }

  // --- TIME AND GREETING HELPERS ---
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  String _getWorkoutName(List<String> goals) {
    final lowerGoals = goals.map((g) => g.toLowerCase()).toList();
    if (lowerGoals.contains('lose weight') && lowerGoals.contains('build muscle')) {
      return 'Body Recomp: Power & Burn';
    }
    
    final primaryGoal = goals.isNotEmpty ? goals.first : 'Maintain';
    switch (primaryGoal.toLowerCase()) {
      case 'lose weight':
        return 'Fat Shred & HIIT Blast';
      case 'build muscle':
        return 'Hypertrophy Chest & Triceps';
      case 'improve endurance':
        return 'Cardio Conditioning & Core';
      case 'maintain':
      default:
        return 'Functional Full Body Core';
    }
  }

  List<Exercise> _getExercisesForGoal(List<String> goals, bool isMetric) {
    final double weight = isMetric ? 12.0 : 25.0; // Standard starter weight
    final lowerGoals = goals.map((g) => g.toLowerCase()).toList();

    // Blended Body Recomposition Workout
    if (lowerGoals.contains('lose weight') && lowerGoals.contains('build muscle')) {
      return [
        Exercise(name: 'Dumbbell Bench Press', category: 'Chest', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 10, weight: weight))),
        Exercise(name: 'Bodyweight Squats', category: 'Legs', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 20, weight: 0))),
        Exercise(name: 'Dumbbell Bent-over Rows', category: 'Back', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 12, weight: weight))),
        Exercise(name: 'Burpees', category: 'Cardio', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 10, weight: 0))),
      ];
    }

    final primaryGoal = goals.isNotEmpty ? goals.first : 'Maintain';
    switch (primaryGoal.toLowerCase()) {
      case 'lose weight':
        return [
          Exercise(name: 'Jumping Jacks', category: 'Cardio', sets: List.generate(4, (i) => ExerciseSet(setNumber: i+1, reps: 45, weight: 0))),
          Exercise(name: 'Bodyweight Squats', category: 'Legs', sets: List.generate(4, (i) => ExerciseSet(setNumber: i+1, reps: 20, weight: 0))),
          Exercise(name: 'Mountain Climbers', category: 'Core', sets: List.generate(4, (i) => ExerciseSet(setNumber: i+1, reps: 30, weight: 0))),
          Exercise(name: 'Burpees', category: 'Cardio', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 10, weight: 0))),
        ];
      case 'build muscle':
        return [
          Exercise(name: 'Dumbbell Bench Press', category: 'Chest', sets: List.generate(4, (i) => ExerciseSet(setNumber: i+1, reps: 10, weight: weight))),
          Exercise(name: 'Overhead Shoulder Press', category: 'Shoulders', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 12, weight: weight - 4))),
          Exercise(name: 'Incline Dumbbell Flys', category: 'Chest', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 12, weight: weight - 2))),
          Exercise(name: 'Bench Tricep Dips', category: 'Triceps', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 15, weight: 0))),
        ];
      case 'improve endurance':
        return [
          Exercise(name: 'Jump Rope', category: 'Cardio', sets: List.generate(4, (i) => ExerciseSet(setNumber: i+1, reps: 60, weight: 0))),
          Exercise(name: 'High Knees', category: 'Cardio', sets: List.generate(4, (i) => ExerciseSet(setNumber: i+1, reps: 40, weight: 0))),
          Exercise(name: 'Plank Shoulder Taps', category: 'Core', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 24, weight: 0))),
          Exercise(name: 'Bicycle Crunches', category: 'Core', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 20, weight: 0))),
        ];
      case 'maintain':
      default:
        return [
          Exercise(name: 'Push-ups', category: 'Chest', sets: List.generate(4, (i) => ExerciseSet(setNumber: i+1, reps: 15, weight: 0))),
          Exercise(name: 'Walking Lunges', category: 'Legs', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 20, weight: 0))),
          Exercise(name: 'Dumbbell Bent-over Rows', category: 'Back', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 12, weight: weight))),
          Exercise(name: 'Standard Forearm Plank', category: 'Core', sets: List.generate(3, (i) => ExerciseSet(setNumber: i+1, reps: 45, weight: 0))),
        ];
    }
  }

  List<DateTime> _getWeekDays() {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Monday
    return List.generate(7, (index) => firstDayOfWeek.add(Duration(days: index)));
  }

  bool _isWorkoutCompletedOnDate(List<WorkoutSession> completed, DateTime date) {
    return completed.any((sess) => sess.isCompleted && DateUtils.isSameDay(sess.startTime, date));
  }

  int _getCompletedThisWeekCount(List<WorkoutSession> completed) {
    final weekDays = _getWeekDays();
    final startOfWeek = weekDays.first;
    final endOfWeek = weekDays.last.add(const Duration(hours: 23, minutes: 59));
    
    // Count unique days where a workout was completed
    final completedDays = <String>{};
    for (var session in completed) {
      if (session.isCompleted && session.startTime.isAfter(startOfWeek) && session.startTime.isBefore(endOfWeek)) {
        completedDays.add(DateFormat('yyyy-MM-dd').format(session.startTime));
      }
    }
    return completedDays.length;
  }

  Widget _buildBurnAndWeightLossCard(WorkoutState state, UserProfile profile, BuildContext context, WidgetRef ref, bool isDark) {
    final today = DateTime.now();
    final todayActivities = state.loggedActivities.where((a) => DateUtils.isSameDay(a.timestamp, today)).toList();
    final int totalBurnedToday = todayActivities.fold(0, (sum, a) => sum + a.caloriesBurned);

    final totalBurnedAllTime = state.loggedActivities.fold(0, (sum, a) => sum + a.caloriesBurned);
    final double weightLoss = totalBurnedAllTime / (profile.isMetric ? 7700.0 : 3500.0);
    final String unitStr = profile.isMetric ? 'kg' : 'lbs';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? FuelixTheme.darkCard : Colors.white,
        borderRadius: FuelixTheme.cardRadius,
        boxShadow: FuelixTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Activity Burn & Weight Loss',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddActivityDialog(context, ref, profile),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Log'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$totalBurnedToday kcal',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: FuelixTheme.accentOrange),
                  ),
                  const SizedBox(height: 4),
                  const Text('Burned Today', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(
                height: 32,
                child: VerticalDivider(width: 1),
              ),
              Column(
                children: [
                  Text(
                    '${weightLoss.toStringAsFixed(3)} $unitStr',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: FuelixTheme.accentLime),
                  ),
                  const SizedBox(height: 4),
                  Text('Est. Weight Loss', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          if (todayActivities.isNotEmpty) ...[
            const Divider(height: 24),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayActivities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final activity = todayActivities[index];
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '${activity.durationMinutes.round()} mins • ${activity.intensity} intensity${activity.carriesExtraLoad ? ' • +Load' : ''}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '-${activity.caloriesBurned} kcal',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                          onPressed: () => ref.read(workoutProvider.notifier).deleteActivity(activity.id),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(left: 8),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showAddActivityDialog(BuildContext context, WidgetRef ref, UserProfile profile) {
    showDialog(
      context: context,
      builder: (context) => _AddActivityDialog(profile: profile),
    );
  }
}

class _AddActivityDialog extends StatefulWidget {
  final UserProfile profile;
  const _AddActivityDialog({required this.profile});

  @override
  State<_AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<_AddActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController();
  
  String _selectedExercise = 'Running';
  String _selectedIntensity = 'Moderate';
  bool _carriesExtraLoad = false;

  final List<String> _exercisesList = [
    'Running',
    'Cycling / Biking',
    'Swimming',
    'Weightlifting / Strength',
    'HIIT / Cardio Blast',
    'Yoga / Stretching',
    'Other General Workout'
  ];

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      title: const Text('Log Custom Activity'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Exercise Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedExercise,
                dropdownColor: isDark ? FuelixTheme.darkCard : Colors.white,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _exercisesList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _selectedExercise = val!),
              ),
              const SizedBox(height: 16),
              const Text('Duration (Minutes)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'e.g. 30',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter duration';
                  if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Enter positive number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Exercise Intensity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedIntensity,
                dropdownColor: isDark ? FuelixTheme.darkCard : Colors.white,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'Low', child: Text('Low Intensity')),
                  DropdownMenuItem(value: 'Moderate', child: Text('Moderate Intensity')),
                  DropdownMenuItem(value: 'Extreme', child: Text('Extreme Intensity')),
                ],
                onChanged: (val) => setState(() => _selectedIntensity = val!),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weighted Load?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('Weighted vest or extra load', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _carriesExtraLoad,
                    onChanged: (val) => setState(() => _carriesExtraLoad = val),
                    activeColor: FuelixTheme.accentOrange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        Consumer(
          builder: (context, ref, _) => ElevatedButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              
              final duration = double.parse(_durationController.text);
              
              ref.read(workoutProvider.notifier).logActivity(
                name: _selectedExercise,
                durationMinutes: duration,
                intensity: _selectedIntensity,
                carriesExtraLoad: _carriesExtraLoad,
                userWeightKg: widget.profile.weightKg,
              );
              
              Navigator.of(context).pop();
            },
            child: const Text('Save Burn'),
          ),
        ),
      ],
    );
  }
}
