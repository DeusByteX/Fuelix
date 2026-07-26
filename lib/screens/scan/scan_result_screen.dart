import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/nutrition_result.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';

enum ScanMode { photo, barcode }

class ScanResultScreen extends ConsumerStatefulWidget {
  final NutritionResult nutritionResult;
  final ScanMode scanMode;
  final File? localImageFile;

  const ScanResultScreen({
    super.key,
    required this.nutritionResult,
    required this.scanMode,
    this.localImageFile,
  });

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late double _portionGrams;
  String _selectedCategory = _smartCategory();
  bool _microsExpanded = false;
  bool _isSaving = false;

  late AnimationController _entryController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.nutritionResult.foodName);
    _portionGrams = widget.nutritionResult.portionGrams;

    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
            begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryController, curve: Curves.easeOutCubic));
    _entryController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  static String _smartCategory() {
    final h = DateTime.now().hour;
    if (h < 10) return 'Breakfast';
    if (h < 14) return 'Lunch';
    if (h < 18) return 'Snacks';
    return 'Dinner';
  }

  // Per-gram base values (from the portionGrams returned by AI/barcode)
  NutritionResult get _base => widget.nutritionResult;
  double get _multiplier => _portionGrams / _base.portionGrams;

  double get calories => _base.calories * _multiplier;
  double get protein  => _base.protein  * _multiplier;
  double get carbs    => _base.carbs    * _multiplier;
  double get fat      => _base.fat      * _multiplier;
  double get vitA     => _base.vitaminA * _multiplier;
  double get vitC     => _base.vitaminC * _multiplier;
  double get vitD     => _base.vitaminD * _multiplier;
  double get calcium  => _base.calcium  * _multiplier;
  double get iron     => _base.iron     * _multiplier;
  double get potassium => _base.potassium * _multiplier;

  Future<void> _logMeal() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(dietProvider.notifier).addMeal(
            name: name,
            category: _selectedCategory,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            vitA: vitA,
            vitC: vitC,
            vitD: vitD,
            calcium: calcium,
            iron: iron,
            potassium: potassium,
            portionMultiplier: _multiplier,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ $name logged to $_selectedCategory'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context)
            .popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to log: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: isDark ? FuelixTheme.darkBg : FuelixTheme.lightBg,
      body: FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: _slideUp,
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(isDark),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),
                    _buildCalorieHero(isDark),
                    const SizedBox(height: 20),
                    _buildMacroCard(isDark, profile),
                    const SizedBox(height: 16),
                    _buildPortionSlider(isDark),
                    const SizedBox(height: 16),
                    _buildMealCategory(isDark),
                    const SizedBox(height: 16),
                    _buildMicrosCard(isDark),
                    const SizedBox(height: 16),
                    _buildSourceTag(isDark),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildLogButton(isDark),
    );
  }

  // ─── SLIVER APP BAR WITH FOOD IMAGE ──────────────────────────────────────

  Widget _buildSliverAppBar(bool isDark) {
    final hasLocalImage = widget.localImageFile != null;
    final hasNetworkImage = _base.photoUrl != null && _base.photoUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: isDark ? FuelixTheme.darkCard : Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('Nutrition Result',
          style: TextStyle(fontWeight: FontWeight.bold)),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasLocalImage)
              Image.file(widget.localImageFile!, fit: BoxFit.cover)
            else if (hasNetworkImage)
              Image.network(_base.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagePlaceholder())
            else
              _imagePlaceholder(),
            // Gradient overlay
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FuelixTheme.accentOrange.withValues(alpha: 0.3),
            Colors.deepOrange.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: const Icon(Icons.restaurant_rounded,
          size: 80, color: FuelixTheme.accentOrange),
    );
  }

  // ─── CALORIE HERO ─────────────────────────────────────────────────────────

  Widget _buildCalorieHero(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FuelixTheme.accentOrange, Color(0xFFFF3D00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: FuelixTheme.accentOrange.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // Editable name
          TextFormField(
            controller: _nameController,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              hintText: 'Food name',
              hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              suffixIcon: Icon(Icons.edit_rounded, color: Colors.white54, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${calories.round()}',
                    style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0),
                  ),
                  const Text('kcal',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _heroMini('${protein.round()}g', 'Protein'),
                  const SizedBox(height: 6),
                  _heroMini('${carbs.round()}g', 'Carbs'),
                  const SizedBox(height: 6),
                  _heroMini('${fat.round()}g', 'Fat'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMini(String value, String label) {
    return Row(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  // ─── MACRO PROGRESS CARD ──────────────────────────────────────────────────

  Widget _buildMacroCard(bool isDark, dynamic profile) {
    final carbTarget = profile?.dailyCarbsTarget.toDouble() ?? 250;
    final proteinTarget = profile?.dailyProteinTarget.toDouble() ?? 150;
    final fatTarget = profile?.dailyFatTarget.toDouble() ?? 80;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Macronutrients',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _macroBar('Carbohydrates', carbs, carbTarget, FuelixTheme.accentOrange),
          const SizedBox(height: 12),
          _macroBar('Protein', protein, proteinTarget, FuelixTheme.accentLime),
          const SizedBox(height: 12),
          _macroBar('Fat', fat, fatTarget, const Color(0xFF00C2FF)),
        ],
      ),
    );
  }

  Widget _macroBar(String label, double value, double target, Color color) {
    final pct = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    final pctLabel =
        target > 0 ? '${((value / target) * 100).round()}% DV' : '';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${value.round()}g  $pctLabel',
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 9,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ─── PORTION SLIDER ───────────────────────────────────────────────────────

  Widget _buildPortionSlider(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Adjust Portion',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: FuelixTheme.accentOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_portionGrams.round()}g',
                  style: const TextStyle(
                      color: FuelixTheme.accentOrange,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 20),
              activeTrackColor: FuelixTheme.accentOrange,
              inactiveTrackColor:
                  FuelixTheme.accentOrange.withValues(alpha: 0.15),
              thumbColor: FuelixTheme.accentOrange,
            ),
            child: Slider(
              value: _portionGrams.clamp(25.0, 800.0),
              min: 25,
              max: 800,
              divisions: 155,
              onChanged: (v) => setState(() => _portionGrams = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('25g', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('800g', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── MEAL CATEGORY ────────────────────────────────────────────────────────

  Widget _buildMealCategory(bool isDark) {
    const categories = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Meal Type',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: categories
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedCategory = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedCategory == c
                                  ? FuelixTheme.accentOrange
                                  : FuelixTheme.accentOrange
                                      .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              c,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _selectedCategory == c
                                    ? Colors.white
                                    : FuelixTheme.accentOrange,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─── MICRONUTRIENTS ───────────────────────────────────────────────────────

  Widget _buildMicrosCard(bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _microsExpanded = !_microsExpanded),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(isDark),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.biotech_rounded,
                        size: 20, color: FuelixTheme.accentLime),
                    SizedBox(width: 8),
                    Text('Vitamins & Minerals',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
                Icon(_microsExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded),
              ],
            ),
            if (_microsExpanded) ...[
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.3,
                children: [
                  _microChip('Vitamin A', '${vitA.round()} mcg', FuelixTheme.accentOrange),
                  _microChip('Vitamin C', '${vitC.round()} mg', FuelixTheme.accentLime),
                  _microChip('Vitamin D', '${vitD.toStringAsFixed(1)} mcg', const Color(0xFFFFD700)),
                  _microChip('Calcium', '${calcium.round()} mg', const Color(0xFF00C2FF)),
                  _microChip('Iron', '${iron.toStringAsFixed(1)} mg', Colors.redAccent),
                  _microChip('Potassium', '${potassium.round()} mg', const Color(0xFF9C27B0)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _microChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  // ─── SOURCE TAG ───────────────────────────────────────────────────────────

  Widget _buildSourceTag(bool isDark) {
    final sourceMap = {
      'gemini+usda': ('Gemini AI + USDA', Icons.auto_awesome_rounded, Colors.deepPurple),
      'barcode': ('Open Food Facts', Icons.qr_code_rounded, Colors.teal),
      'cache': ('Cached Result', Icons.cached_rounded, Colors.blue),
      'search': ('USDA Database', Icons.search_rounded, Colors.orange),
      'mock': ('Demo Data', Icons.science_rounded, Colors.grey),
      'fallback': ('Estimated Data', Icons.warning_amber_rounded, Colors.orange),
    };
    final (label, icon, color) =
        sourceMap[_base.source] ?? ('Unknown', Icons.info_outline_rounded, Colors.grey);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          'Data source: $label',
          style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }

  // ─── LOG BUTTON ───────────────────────────────────────────────────────────

  Widget _buildLogButton(bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SizedBox(
          height: 58,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _logMeal,
            style: ElevatedButton.styleFrom(
              backgroundColor: FuelixTheme.accentOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 8,
              shadowColor: FuelixTheme.accentOrange.withValues(alpha: 0.4),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 22),
                      SizedBox(width: 10),
                      Text('Log Meal to Diary',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(bool isDark) => BoxDecoration(
        color: isDark ? FuelixTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: FuelixTheme.softShadow,
      );
}
