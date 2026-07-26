import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/meal_log.dart';
import '../../models/workout.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  final TextEditingController _weightController = TextEditingController();
  List<MealLog> _last7DaysMeals = [];
  bool _mealsLoading = true;

  @override
  void initState() {
    super.initState();
    _load7DaysNutrition();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _load7DaysNutrition() async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;
    
    try {
      final db = ref.read(databaseServiceProvider);
      final list = await db.getMealLogsForRange(profile.uid, 7);
      setState(() {
        _last7DaysMeals = list;
        _mealsLoading = false;
      });
    } catch (e) {
      debugPrint("Failed to load range meals: $e");
    }
  }

  void _showLogWeightDialog(bool isMetric) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Current Weight'),
        content: TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Weight (${isMetric ? 'kg' : 'lbs'})',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(_weightController.text);
              if (val != null) {
                // Convert back to Kg if entered in lbs
                final kgVal = isMetric ? val : val / 2.20462;
                await ref.read(userProfileProvider.notifier).updateWeight(kgVal);
                ref.invalidate(weightLogsProvider);
                _weightController.clear();
                _load7DaysNutrition(); // Reload data
                if (mounted) Navigator.of(context).pop();
              }
            },
            child: const Text('Log Weight'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(userProfileProvider);
    final weightLogsAsync = ref.watch(weightLogsProvider);
    final workoutState = ref.watch(workoutProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final weightUnit = profile.isMetric ? 'kg' : 'lbs';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart_rounded, color: FuelixTheme.accentOrange),
            onPressed: () => _showLogWeightDialog(profile.isMetric),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Weight Trend Section
              const Text('Weight Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                height: 240,
                padding: const EdgeInsets.only(top: 24, bottom: 12, right: 24, left: 12),
                decoration: BoxDecoration(
                  color: isDark ? FuelixTheme.darkCard : Colors.white,
                  borderRadius: FuelixTheme.cardRadius,
                  boxShadow: FuelixTheme.softShadow,
                ),
                child: weightLogsAsync.when(
                  data: (logs) {
                    if (logs.isEmpty) {
                      return const Center(child: Text('No weight records yet. Tap top right to log!'));
                    }
                    return _buildWeightChart(logs, profile.isMetric, isDark);
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading chart: $err')),
                ),
              ),
              const SizedBox(height: 28),

              // 2. Calorie Intake vs Target Section
              const Text('Daily Calorie Intake (Last 7 Days)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                height: 240,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? FuelixTheme.darkCard : Colors.white,
                  borderRadius: FuelixTheme.cardRadius,
                  boxShadow: FuelixTheme.softShadow,
                ),
                child: _mealsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCalorieChart(_last7DaysMeals, profile.dailyCalorieTarget, isDark),
              ),
              const SizedBox(height: 28),

              // 3. Workout Consistency (Last 30 days)
              const Text('Workout Consistency (Last 30 Days)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? FuelixTheme.darkCard : Colors.white,
                  borderRadius: FuelixTheme.cardRadius,
                  boxShadow: FuelixTheme.softShadow,
                ),
                child: Column(
                  children: [
                    _buildConsistencyGrid(workoutState.completedSessions, isDark),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(FuelixTheme.accentOrange, 'Workout Day'),
                        const SizedBox(width: 24),
                        _buildLegendItem(isDark ? FuelixTheme.darkBg : Colors.grey[100]!, 'Rest Day'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // --- WEIGHT TREND LINE CHART ---
  Widget _buildWeightChart(List<Map<String, dynamic>> logs, bool isMetric, bool isDark) {
    final spots = <FlSpot>[];
    double minY = 200;
    double maxY = 0;

    for (int i = 0; i < logs.length; i++) {
      final item = logs[i];
      final rawWeight = (item['weightKg'] as num).toDouble();
      final weight = isMetric ? rawWeight : rawWeight * 2.20462;
      
      spots.add(FlSpot(i.toDouble(), weight));

      if (weight < minY) minY = weight;
      if (weight > maxY) maxY = weight;
    }

    // Add visual margins to the top and bottom of chart axes
    minY = (minY - 5).clamp(0, double.infinity);
    maxY = maxY + 5;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.grey[200]!,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < logs.length) {
                  final date = DateTime.parse(logs[idx]['date']);
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      DateFormat('MM/dd').format(date),
                      style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 22,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: FuelixTheme.accentOrange,
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: FuelixTheme.accentOrange.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }

  // --- CALORIE INTAKE BAR CHART ---
  Widget _buildCalorieChart(List<MealLog> meals, int targetCal, bool isDark) {
    // Group meals by past 7 calendar days
    final List<DateTime> past7Days = List.generate(7, (i) {
      final date = DateTime.now().subtract(Duration(days: 6 - i));
      return DateTime(date.year, date.month, date.day);
    });

    final Map<DateTime, double> dailyTotals = {};
    for (var day in past7Days) {
      dailyTotals[day] = 0;
    }

    for (var meal in meals) {
      final mealDate = DateTime(meal.date.year, meal.date.month, meal.date.day);
      if (dailyTotals.containsKey(mealDate)) {
        dailyTotals[mealDate] = dailyTotals[mealDate]! + meal.calories;
      }
    }

    final barGroups = <BarChartGroupData>[];
    double maxVal = targetCal.toDouble();

    for (int i = 0; i < past7Days.length; i++) {
      final day = past7Days[i];
      final total = dailyTotals[day]!;
      if (total > maxVal) maxVal = total;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: total,
              color: total > targetCal ? Colors.greenAccent : FuelixTheme.accentOrange,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            )
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal + 300,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value % 500 == 0) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      '${value.toInt()}',
                      style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < past7Days.length) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      DateFormat('E').format(past7Days[idx]),
                      style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.grey[200]!,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        // Dotted Target Line
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: targetCal.toDouble(),
              color: isDark ? Colors.white38 : Colors.black38,
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                labelResolver: (line) => 'Target (${targetCal}k)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WORKOUT STREAK HEATMAP GRID ---
  Widget _buildConsistencyGrid(List<WorkoutSession> sessions, bool isDark) {
    final today = DateTime.now();
    final List<DateTime> last30Days = List.generate(30, (i) {
      final date = today.subtract(Duration(days: 29 - i));
      return DateTime(date.year, date.month, date.day);
    });

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: last30Days.map((date) {
        final hasWorkout = sessions.any(
          (s) => s.isCompleted && DateUtils.isSameDay(s.startTime, date),
        );
        final isToday = DateUtils.isSameDay(date, today);

        return Tooltip(
          message: DateFormat('MMM d').format(date),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: hasWorkout
                  ? FuelixTheme.accentOrange
                  : (isDark ? FuelixTheme.darkBg : Colors.grey[100]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isToday ? FuelixTheme.accentOrange : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                date.day.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: hasWorkout
                      ? Colors.white
                      : (isToday
                          ? FuelixTheme.accentOrange
                          : (isDark ? Colors.white30 : Colors.black26)),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
