import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/meal_log.dart';
import '../../models/user_profile.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';

class DietTab extends ConsumerStatefulWidget {
  const DietTab({super.key});

  @override
  ConsumerState<DietTab> createState() => _DietTabState();
}

class _DietTabState extends ConsumerState<DietTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _searchLoading = false;
  Map<String, double>? _searchResult;
  String? _searchedFoodName;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchLoading = true;
      _searchResult = null;
      _searchedFoodName = null;
    });

    try {
      final api = ref.read(nutritionApiServiceProvider);
      final result = await api.fetchFoodNutrition(query);
      setState(() {
        _searchResult = result;
        _searchedFoodName = query;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to find nutrition data: $e')),
      );
    } finally {
      setState(() {
        _searchLoading = false;
      });
    }
  }

  void _showLogFoodDialog(String foodName, Map<String, double> nutrition) {
    showDialog(
      context: context,
      builder: (context) => LogFoodDialog(
        foodName: foodName,
        nutrition: nutrition,
        onLog: (category, multiplier) {
          ref.read(dietProvider.notifier).addMeal(
                name: foodName,
                category: category,
                calories: nutrition['calories']!,
                protein: nutrition['protein']!,
                carbs: nutrition['carbs']!,
                fat: nutrition['fat']!,
                vitA: nutrition['vitaminA'] ?? 0,
                vitC: nutrition['vitaminC'] ?? 0,
                vitD: nutrition['vitaminD'] ?? 0,
                calcium: nutrition['calcium'] ?? 0,
                iron: nutrition['iron'] ?? 0,
                potassium: nutrition['potassium'] ?? 0,
                portionMultiplier: multiplier,
              );
          setState(() {
            _isSearching = false;
            _searchController.clear();
            _searchResult = null;
          });
        },
      ),
    );
  }

  void _showEditMealDialog(MealLog meal) {
    showDialog(
      context: context,
      builder: (context) => EditMealDialog(
        meal: meal,
        onUpdate: (multiplier) {
          final updated = meal.copyWith(portionSizeMultiplier: multiplier);
          ref.read(dietProvider.notifier).updateMeal(updated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(userProfileProvider);
    final dietState = ref.watch(dietProvider);

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final targetCalories = profile.dailyCalorieTarget;
    final consumedCalories = dietState.totalCalories;
    final remainingCalories = targetCalories - consumedCalories;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Calendar Bar
            _buildCalendarBar(dietState, isDark),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Calorie & Macro Header Cards
                    _buildCalorieHeader(targetCalories.toDouble(), consumedCalories, remainingCalories, isDark),
                    const SizedBox(height: 20),
                    _buildMacroBars(dietState, profile, isDark),
                    const SizedBox(height: 16),
                    _buildSafeMinimumsCard(profile, isDark),
                    const SizedBox(height: 24),

                    // Manual Search / Add food fallback
                    _buildSearchSection(isDark),
                    const SizedBox(height: 24),

                    if (!_isSearching) ...[
                      // Meal Categories List
                      _buildMealCategorySection('Breakfast', dietState.mealLogs, isDark),
                      const SizedBox(height: 16),
                      _buildMealCategorySection('Lunch', dietState.mealLogs, isDark),
                      const SizedBox(height: 16),
                      _buildMealCategorySection('Dinner', dietState.mealLogs, isDark),
                      const SizedBox(height: 16),
                      _buildMealCategorySection('Snacks', dietState.mealLogs, isDark),
                      const SizedBox(height: 32),
                    ] else ...[
                      _buildSearchResults(isDark),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CALENDAR WIDGET ---
  Widget _buildCalendarBar(DietState state, bool isDark) {
    final formattedDate = DateFormat('EEEE, MMMM d').format(state.selectedDate);
    final isToday = DateUtils.isSameDay(state.selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? FuelixTheme.darkCard : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prev = state.selectedDate.subtract(const Duration(days: 1));
              ref.read(dietProvider.notifier).changeDate(prev);
            },
          ),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: FuelixTheme.accentOrange),
              const SizedBox(width: 8),
              Text(
                isToday ? 'Today ($formattedDate)' : formattedDate,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final next = state.selectedDate.add(const Duration(days: 1));
              ref.read(dietProvider.notifier).changeDate(next);
            },
          ),
        ],
      ),
    );
  }

  // --- CALORIE CARD ---
  Widget _buildCalorieHeader(double target, double consumed, double remaining, bool isDark) {
    final remainingColor = remaining >= 0 ? FuelixTheme.accentOrange : Colors.greenAccent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? FuelixTheme.darkCard : Colors.white,
        borderRadius: FuelixTheme.cardRadius,
        boxShadow: FuelixTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(target.round().toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Target kcal', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const Icon(Icons.horizontal_rule_rounded, color: Colors.grey, size: 16),
              Column(
                children: [
                  Text(consumed.round().toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Logged kcal', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 16),
              Column(
                children: [
                  Text(
                    remaining.round().abs().toString(),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: remainingColor),
                  ),
                  const SizedBox(height: 4),
                  Text(remaining >= 0 ? 'Kcal Left' : 'Kcal Over', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: remainingColor)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- MACRO SLIDERS ---
  Widget _buildMacroBars(DietState state, UserProfile profile, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? FuelixTheme.darkCard : Colors.white,
        borderRadius: FuelixTheme.cardRadius,
        boxShadow: FuelixTheme.softShadow,
      ),
      child: Column(
        children: [
          _buildMacroLine('Carbohydrates', state.totalCarbs.round(), profile.dailyCarbsTarget, FuelixTheme.accentOrange, isDark),
          const SizedBox(height: 14),
          _buildMacroLine('Protein', state.totalProtein.round(), profile.dailyProteinTarget, FuelixTheme.accentLime, isDark),
          const SizedBox(height: 14),
          _buildMacroLine('Fats', state.totalFat.round(), profile.dailyFatTarget, const Color(0xFF00C2FF), isDark),
        ],
      ),
    );
  }

  Widget _buildMacroLine(String label, int value, int target, Color color, bool isDark) {
    final pct = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text('$value / $target g', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: isDark ? FuelixTheme.darkBg : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // --- DATABASE SEARCH FIELD ---
  Widget _buildSearchSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? FuelixTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: FuelixTheme.softShadow,
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: 'Search food database (USDA)...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                      _searchResult = null;
                    });
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _performSearch,
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: (val) => _performSearch(),
      ),
    );
  }

  // --- SEARCH RESULTS SUB-PANEL ---
  Widget _buildSearchResults(bool isDark) {
    if (_searchLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_searchResult == null || _searchedFoodName == null) {
      return const SizedBox.shrink();
    }

    final nutrients = _searchResult!;
    return Card(
      color: isDark ? FuelixTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: FuelixTheme.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _searchedFoodName!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: FuelixTheme.accentOrange, size: 28),
                  onPressed: () => _showLogFoodDialog(_searchedFoodName!, nutrients),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSearchNutrient('Calories', '${nutrients['calories']!.round()} kcal'),
                _buildSearchNutrient('Protein', '${nutrients['protein']!.round()}g'),
                _buildSearchNutrient('Carbs', '${nutrients['carbs']!.round()}g'),
                _buildSearchNutrient('Fat', '${nutrients['fat']!.round()}g'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchNutrient(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // --- MEAL LOG SECTIONS BY CATEGORY ---
  Widget _buildMealCategorySection(String category, List<MealLog> logs, bool isDark) {
    final filtered = logs.where((m) => m.mealCategory == category).toList();
    final categoryCalories = filtered.fold(0.0, (sum, m) => sum + m.calories);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? FuelixTheme.darkCard : Colors.white,
        borderRadius: FuelixTheme.cardRadius,
        boxShadow: FuelixTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${categoryCalories.round()} kcal',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: FuelixTheme.accentOrange),
              ),
            ],
          ),
          const Divider(height: 20),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No logs for $category. Tap camera below to scan!',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 12, thickness: 0.5),
              itemBuilder: (context, index) {
                final meal = filtered[index];
                return Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showEditMealDialog(meal),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Portion: ${meal.portionSizeMultiplier.toStringAsFixed(1)}x • P: ${meal.protein.round()}g C: ${meal.carbs.round()}g F: ${meal.fat.round()}g',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      '${meal.calories.round()} kcal',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => ref.read(dietProvider.notifier).deleteMeal(meal.id),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSafeMinimumsCard(UserProfile profile, bool isDark) {
    const minCal = 1200;
    final minProtein = (profile.weightKg * 0.8).round();
    final minFat = (profile.weightKg * 0.4).round();
    const minCarbs = 50;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? FuelixTheme.darkCard : Colors.white,
        borderRadius: FuelixTheme.cardRadius,
        boxShadow: FuelixTheme.softShadow,
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.orangeAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Daily Safe Minimums',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : FuelixTheme.textDarkPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'For optimal metabolic safety, ensure your daily intake does not drop below these minimum limits:',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMinMetricItem('Calories', '$minCal kcal', Icons.local_fire_department_rounded, Colors.orangeAccent),
              _buildMinMetricItem('Protein', '$minProtein g', Icons.fitness_center_rounded, FuelixTheme.accentLime),
              _buildMinMetricItem('Carbs', '$minCarbs g', Icons.grain_rounded, FuelixTheme.accentOrange),
              _buildMinMetricItem('Fats', '$minFat g', Icons.opacity_rounded, const Color(0xFF00C2FF)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// --- PORTION LOG DIALOG ---
class LogFoodDialog extends StatefulWidget {
  final String foodName;
  final Map<String, double> nutrition;
  final Function(String category, double multiplier) onLog;

  const LogFoodDialog({
    super.key,
    required this.foodName,
    required this.nutrition,
    required this.onLog,
  });

  @override
  State<LogFoodDialog> createState() => _LogFoodDialogState();
}

class _LogFoodDialogState extends State<LogFoodDialog> {
  double _multiplier = 1.0;
  String _category = 'Breakfast';

  @override
  Widget build(BuildContext context) {
    final calories = widget.nutrition['calories']! * _multiplier;
    final protein = widget.nutrition['protein']! * _multiplier;
    final carbs = widget.nutrition['carbs']! * _multiplier;
    final fat = widget.nutrition['fat']! * _multiplier;

    return AlertDialog(
      title: const Text('Log Food Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.foodName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Select Meal Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            DropdownButton<String>(
              value: _category,
              isExpanded: true,
              items: ['Breakfast', 'Lunch', 'Dinner', 'Snacks']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Adjust Portion Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('${_multiplier.toStringAsFixed(1)}x', style: const TextStyle(fontWeight: FontWeight.bold, color: FuelixTheme.accentOrange)),
              ],
            ),
            Slider(
              value: _multiplier,
              min: 0.1,
              max: 3.0,
              divisions: 29,
              activeColor: FuelixTheme.accentOrange,
              onChanged: (val) => setState(() => _multiplier = val),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildItem('kcal', calories.round()),
                _buildItem('P', protein.round()),
                _buildItem('C', carbs.round()),
                _buildItem('F', fat.round()),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onLog(_category, _multiplier);
            Navigator.of(context).pop();
          },
          child: const Text('Log Meal'),
        ),
      ],
    );
  }

  Widget _buildItem(String label, int val) {
    return Column(
      children: [
        Text(val.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

// --- PORTION EDIT DIALOG ---
class EditMealDialog extends StatefulWidget {
  final MealLog meal;
  final Function(double multiplier) onUpdate;

  const EditMealDialog({
    super.key,
    required this.meal,
    required this.onUpdate,
  });

  @override
  State<EditMealDialog> createState() => _EditMealDialogState();
}

class _EditMealDialogState extends State<EditMealDialog> {
  late double _multiplier;

  @override
  void initState() {
    super.initState();
    _multiplier = widget.meal.portionSizeMultiplier;
  }

  @override
  Widget build(BuildContext context) {
    final calories = widget.meal.baseCalories * _multiplier;
    final protein = widget.meal.baseProtein * _multiplier;
    final carbs = widget.meal.baseCarbs * _multiplier;
    final fat = widget.meal.baseFat * _multiplier;

    return AlertDialog(
      title: const Text('Edit Portion Size'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.meal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Adjust serving size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('${_multiplier.toStringAsFixed(1)}x', style: const TextStyle(fontWeight: FontWeight.bold, color: FuelixTheme.accentOrange)),
            ],
          ),
          Slider(
            value: _multiplier,
            min: 0.1,
            max: 3.0,
            divisions: 29,
            activeColor: FuelixTheme.accentOrange,
            onChanged: (val) => setState(() => _multiplier = val),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildItem('kcal', calories.round()),
              _buildItem('P', protein.round()),
              _buildItem('C', carbs.round()),
              _buildItem('F', fat.round()),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onUpdate(_multiplier);
            Navigator.of(context).pop();
          },
          child: const Text('Update'),
        ),
      ],
    );
  }

  Widget _buildItem(String label, int val) {
    return Column(
      children: [
        Text(val.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
