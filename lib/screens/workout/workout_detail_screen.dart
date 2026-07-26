import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/workout.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';

class WorkoutDetailScreen extends ConsumerStatefulWidget {
  const WorkoutDetailScreen({super.key});

  @override
  ConsumerState<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends ConsumerState<WorkoutDetailScreen> {
  Timer? _timer;
  int _restTimeRemaining = 0; // In seconds
  int _defaultRestTime = 60; // 60 seconds default

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRestTimer() {
    _timer?.cancel();
    setState(() {
      _restTimeRemaining = _defaultRestTime;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restTimeRemaining > 0) {
        setState(() {
          _restTimeRemaining--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _addRestTime(int seconds) {
    setState(() {
      _restTimeRemaining += seconds;
    });
  }

  void _skipRestTimer() {
    _timer?.cancel();
    setState(() {
      _restTimeRemaining = 0;
    });
  }

  void _toggleSetCompletion(int exerciseIndex, int setIndex, WorkoutSession session) {
    final exercise = session.exercises[exerciseIndex];
    final setItem = exercise.sets[setIndex];
    final updatedSet = setItem.copyWith(isCompleted: !setItem.isCompleted);

    final updatedSets = List<ExerciseSet>.from(exercise.sets);
    updatedSets[setIndex] = updatedSet;

    final updatedExercise = exercise.copyWith(sets: updatedSets);
    final updatedExercises = List<Exercise>.from(session.exercises);
    updatedExercises[exerciseIndex] = updatedExercise;

    final updatedSession = session.copyWith(exercises: updatedExercises);
    ref.read(workoutProvider.notifier).updateActiveWorkout(updatedSession);

    // If marked as completed, trigger rest timer
    if (updatedSet.isCompleted) {
      _startRestTimer();
    }
  }

  void _updateSetDetails(int exerciseIndex, int setIndex, WorkoutSession session, {String? repsStr, String? weightStr}) {
    final exercise = session.exercises[exerciseIndex];
    final setItem = exercise.sets[setIndex];

    int reps = setItem.reps;
    double weight = setItem.weight;

    if (repsStr != null) {
      reps = int.tryParse(repsStr) ?? reps;
    }
    if (weightStr != null) {
      weight = double.tryParse(weightStr) ?? weight;
    }

    final updatedSet = setItem.copyWith(reps: reps, weight: weight);
    final updatedSets = List<ExerciseSet>.from(exercise.sets);
    updatedSets[setIndex] = updatedSet;

    final updatedExercise = exercise.copyWith(sets: updatedSets);
    final updatedExercises = List<Exercise>.from(session.exercises);
    updatedExercises[exerciseIndex] = updatedExercise;

    final updatedSession = session.copyWith(exercises: updatedExercises);
    ref.read(workoutProvider.notifier).updateActiveWorkout(updatedSession);
  }

  Future<void> _completeWorkout() async {
    await ref.read(workoutProvider.notifier).completeWorkout();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Workout Completed & Logged!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final workoutState = ref.watch(workoutProvider);
    final profile = ref.watch(userProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final session = workoutState.activeSession;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: Text('No active workout session found.')),
      );
    }

    final weightUnit = profile?.isMetric ?? true ? 'kg' : 'lbs';

    return Scaffold(
      appBar: AppBar(
        title: Text(session.name),
        actions: [
          TextButton(
            onPressed: () {
              // Confirm cancellation
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancel Workout?'),
                  content: const Text('Are you sure you want to end this workout? All progress logged in this session will be lost.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('No')),
                    TextButton(
                      onPressed: () {
                        ref.read(workoutProvider.notifier).cancelActiveWorkout();
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Yes, Cancel', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Info panel
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: isDark ? FuelixTheme.darkCard : Colors.grey[200],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Started: ${session.startTime.hour}:${session.startTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: FuelixTheme.accentOrange),
                        const SizedBox(width: 4),
                        Text(
                          '${session.exercises.expand((e) => e.sets).where((s) => s.isCompleted).length} Sets Logged',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Exercises List
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: _restTimeRemaining > 0 ? 140 : 100, // Make space for rest timer overlay or finish button
                  ),
                  itemCount: session.exercises.length,
                  itemBuilder: (context, exerciseIndex) {
                    final exercise = session.exercises[exerciseIndex];
                    return _buildExerciseCard(exercise, exerciseIndex, session, weightUnit, isDark);
                  },
                ),
              ),
            ],
          ),

          // Bottom float panel for completing workout
          Positioned(
            left: 20,
            right: 20,
            bottom: _restTimeRemaining > 0 ? 100 : 20,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _completeWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Complete & Log Workout 🎉',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),

          // Rest Timer Overlay Panel
          if (_restTimeRemaining > 0)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: FuelixTheme.accentOrange,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: FuelixTheme.accentOrange.withOpacity(0.35),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'REST PERIOD',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            '$_restTimeRemaining seconds left',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _addRestTime(15),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('+15s'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      onPressed: _skipRestTimer,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise, int exerciseIndex, WorkoutSession session, String weightUnit, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FuelixTheme.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    exercise.category,
                    style: const TextStyle(fontSize: 11, color: FuelixTheme.accentOrange, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Table Header
            Row(
              children: [
                const SizedBox(width: 40, child: Text('SET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(child: Center(child: Text('WEIGHT ($weightUnit)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)))),
                Expanded(child: Center(child: Text('REPS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)))),
                const SizedBox(width: 50, child: Center(child: Text('DONE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)))),
              ],
            ),
            const Divider(height: 16),

            // Sets List
            ...List.generate(exercise.sets.length, (setIndex) {
              final setItem = exercise.sets[setIndex];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    // Set Number
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${setItem.setNumber}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: setItem.isCompleted ? Colors.green : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),

                    // Weight Input
                    Expanded(
                      child: Container(
                        height: 38,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextFormField(
                          initialValue: setItem.weight > 0 ? setItem.weight.toString() : '',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          enabled: !setItem.isCompleted,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            fillColor: isDark ? FuelixTheme.darkBg : Colors.grey[100],
                            filled: true,
                          ),
                          onChanged: (val) => _updateSetDetails(
                            exerciseIndex,
                            setIndex,
                            session,
                            weightStr: val,
                          ),
                        ),
                      ),
                    ),

                    // Reps Input
                    Expanded(
                      child: Container(
                        height: 38,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextFormField(
                          initialValue: setItem.reps > 0 ? setItem.reps.toString() : '',
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          enabled: !setItem.isCompleted,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            fillColor: isDark ? FuelixTheme.darkBg : Colors.grey[100],
                            filled: true,
                          ),
                          onChanged: (val) => _updateSetDetails(
                            exerciseIndex,
                            setIndex,
                            session,
                            repsStr: val,
                          ),
                        ),
                      ),
                    ),

                    // Completed Check
                    SizedBox(
                      width: 50,
                      child: Center(
                        child: IconButton(
                          icon: Icon(
                            setItem.isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                            color: setItem.isCompleted ? Colors.green : Colors.grey,
                          ),
                          onPressed: () => _toggleSetCompletion(exerciseIndex, setIndex, session),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
