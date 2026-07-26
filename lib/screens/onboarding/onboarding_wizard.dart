import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import '../dashboard_shell.dart';

class OnboardingWizard extends ConsumerStatefulWidget {
  const OnboardingWizard({super.key});

  @override
  ConsumerState<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends ConsumerState<OnboardingWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 13;
  bool _isMetric = true;
  String _dietStrictness = 'Moderate';
  bool _isGymActive = false;

  // Questionnaire States
  String _gender = 'Male';
  int _age = 25;
  double _heightCm = 170.0;
  double _weightKg = 70.0;
  double _targetWeightKg = 65.0;
  List<String> _primaryGoals = ['Lose weight'];
  String _activityLevel = 'Moderate';
  String _dietaryPreference = 'No restriction';
  int _workoutDays = 3;
  
  final List<String> _selectedAllergies = [];
  final TextEditingController _customAllergyController = TextEditingController();

  final List<String> _allergyTags = [
    'Gluten-Free', 'Dairy-Free', 'Nut Allergy', 'Soy-Free', 
    'Egg-Free', 'Shellfish-Free', 'Diabetic-Friendly', 'Low-Sodium'
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _customAllergyController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    // Show loading screen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const OnboardingLoadingScreen(),
    );

    // Simulate database write & model computation delay
    await Future.delayed(const Duration(seconds: 3));

    final user = ref.read(authServiceProvider).currentUser;
    if (user != null) {
      final profile = UserProfile(
        uid: user.uid,
        email: user.email,
        name: user.name,
        gender: _gender,
        age: _age,
        heightCm: _heightCm,
        weightKg: _weightKg,
        targetWeightKg: _targetWeightKg,
        primaryGoals: _primaryGoals,
        activityLevel: _activityLevel,
        dietaryPreference: _dietaryPreference,
        workoutDaysPerWeek: _workoutDays,
        allergies: _selectedAllergies,
        isMetric: _isMetric,
        isOnboarded: true,
        themePreference: ref.read(themeModeProvider) == ThemeMode.dark
            ? 'dark'
            : (ref.read(themeModeProvider) == ThemeMode.light ? 'light' : 'system'),
        dietStrictness: _dietStrictness,
        isGymActive: _isGymActive,
      );

      // Save to database/providers
      await ref.read(userProfileProvider.notifier).saveProfile(profile);

      if (mounted) {
        // Pop the loading dialog
        Navigator.of(context).pop();
        // Go to dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardShell()),
        );
      }
    }
  }

  double _cmToFeet(double cm) => cm / 30.48;
  double _feetToCm(double feet) => feet * 30.48;
  double _kgToLb(double kg) => kg * 2.20462;
  double _lbToKg(double lb) => lb / 2.20462;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? FuelixTheme.darkBg : FuelixTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Onboarding Progress Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of $_totalSteps',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isMetric = !_isMetric;
                          });
                        },
                        child: Text(
                          _isMetric ? 'Switch to Imperial' : 'Switch to Metric',
                          style: const TextStyle(color: FuelixTheme.accentOrange),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      backgroundColor: isDark ? FuelixTheme.darkCard : Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(FuelixTheme.accentOrange),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

            // Page Contents
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentStep = page;
                  });
                },
                children: [
                  _buildThemeStep(isDark),
                  _buildGenderStep(isDark),
                  _buildAgeStep(isDark),
                  _buildHeightStep(isDark),
                  _buildWeightStep(isDark),
                  _buildTargetWeightStep(isDark),
                  _buildGoalStep(isDark),
                  _buildActivityStep(isDark),
                  _buildDietStrictnessStep(isDark),
                  _buildGymActiveStep(isDark),
                  _buildDietaryStep(isDark),
                  _buildWorkoutDaysStep(isDark),
                  _buildAllergiesStep(isDark),
                ],
              ),
            ),

            // Footer controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _prevStep,
                      child: Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: Text(
                      _currentStep == _totalSteps - 1 ? 'Build My Plan' : 'Continue',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS FOR EACH STEP ---

  Widget _buildStepContainer({required String title, required String subtitle, required Widget content, required bool isDark}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : FuelixTheme.textDarkPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary,
            ),
          ),
          const SizedBox(height: 40),
          content,
        ],
      ),
    );
  }

  Widget _buildGenderStep(bool isDark) {
    return _buildStepContainer(
      title: 'What is your gender?',
      subtitle: 'We use this to estimate your basal metabolic rate (BMR) accurately.',
      isDark: isDark,
      content: Row(
        children: [
          Expanded(child: _buildSelectCard('Male', Icons.male, _gender == 'Male', () => setState(() => _gender = 'Male'), isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildSelectCard('Female', Icons.female, _gender == 'Female', () => setState(() => _gender = 'Female'), isDark)),
        ],
      ),
    );
  }

  Widget _buildAgeStep(bool isDark) {
    return _buildStepContainer(
      title: 'How old are you?',
      subtitle: 'Metabolic rates change with age. Let us know yours.',
      isDark: isDark,
      content: Column(
        children: [
          Text(
            '$_age years old',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: FuelixTheme.accentOrange),
          ),
          const SizedBox(height: 30),
          Slider(
            value: _age.toDouble(),
            min: 12.0,
            max: 100.0,
            divisions: 88,
            activeColor: FuelixTheme.accentOrange,
            onChanged: (val) => setState(() => _age = val.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildHeightStep(bool isDark) {
    final double displayHeight = _isMetric ? _heightCm : _heightCm / 2.54; // In inches
    final String unitStr = _isMetric ? 'cm' : 'ft\'in\"';

    String getFormattedHeight() {
      if (_isMetric) return '${_heightCm.round()} cm';
      final totalInches = displayHeight.round();
      final ft = totalInches ~/ 12;
      final inch = totalInches % 12;
      return "$ft' $inch\"";
    }

    return _buildStepContainer(
      title: 'How tall are you?',
      subtitle: 'Height is critical for calculating ideal body mass indices.',
      isDark: isDark,
      content: Column(
        children: [
          Text(
            getFormattedHeight(),
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: FuelixTheme.accentOrange),
          ),
          const SizedBox(height: 30),
          Slider(
            value: _isMetric ? _heightCm : (_heightCm / 2.54).clamp(48.0, 84.0),
            min: _isMetric ? 120.0 : 48.0, // 48 inches = 4 feet
            max: _isMetric ? 220.0 : 84.0, // 84 inches = 7 feet
            divisions: _isMetric ? 100 : 36,
            activeColor: FuelixTheme.accentOrange,
            onChanged: (val) {
              setState(() {
                _heightCm = _isMetric ? val : val * 2.54;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeightStep(bool isDark) {
    final double displayWeight = _isMetric ? _weightKg : _weightKg * 2.20462;
    final String unitStr = _isMetric ? 'kg' : 'lbs';

    return _buildStepContainer(
      title: 'What is your current weight?',
      subtitle: 'This will be the starting point of your fitness tracking.',
      isDark: isDark,
      content: Column(
        children: [
          Text(
            '${displayWeight.toStringAsFixed(1)} $unitStr',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: FuelixTheme.accentOrange),
          ),
          const SizedBox(height: 30),
          Slider(
            value: _isMetric ? _weightKg : (_weightKg * 2.20462).clamp(90.0, 400.0),
            min: _isMetric ? 40.0 : 90.0,
            max: _isMetric ? 180.0 : 400.0,
            divisions: _isMetric ? 280 : 310,
            activeColor: FuelixTheme.accentOrange,
            onChanged: (val) {
              setState(() {
                _weightKg = _isMetric ? val : val / 2.20462;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTargetWeightStep(bool isDark) {
    final double displayWeight = _isMetric ? _targetWeightKg : _targetWeightKg * 2.20462;
    final String unitStr = _isMetric ? 'kg' : 'lbs';

    return _buildStepContainer(
      title: 'What is your target weight?',
      subtitle: 'Setting a clear target helps us tailor the daily calorie deficit or surplus.',
      isDark: isDark,
      content: Column(
        children: [
          Text(
            '${displayWeight.toStringAsFixed(1)} $unitStr',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: FuelixTheme.accentOrange),
          ),
          const SizedBox(height: 30),
          Slider(
            value: _isMetric ? _targetWeightKg : (_targetWeightKg * 2.20462).clamp(90.0, 400.0),
            min: _isMetric ? 40.0 : 90.0,
            max: _isMetric ? 180.0 : 400.0,
            divisions: _isMetric ? 280 : 310,
            activeColor: FuelixTheme.accentOrange,
            onChanged: (val) {
              setState(() {
                _targetWeightKg = _isMetric ? val : val / 2.20462;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStep(bool isDark) {
    return _buildStepContainer(
      title: 'What is your primary goal?',
      subtitle: 'We will use this to structure your workout plan and macro split.',
      isDark: isDark,
      content: Column(
        children: [
          _buildChoiceRow('Lose weight', Icons.trending_down_rounded, _primaryGoals.contains('Lose weight'), () => _toggleGoal('Lose weight'), isDark),
          const SizedBox(height: 12),
          _buildChoiceRow('Build muscle', Icons.fitness_center_rounded, _primaryGoals.contains('Build muscle'), () => _toggleGoal('Build muscle'), isDark),
          const SizedBox(height: 12),
          _buildChoiceRow('Maintain', Icons.health_and_safety_rounded, _primaryGoals.contains('Maintain'), () => _toggleGoal('Maintain'), isDark),
          const SizedBox(height: 12),
          _buildChoiceRow('Improve endurance', Icons.speed_rounded, _primaryGoals.contains('Improve endurance'), () => _toggleGoal('Improve endurance'), isDark),
        ],
      ),
    );
  }

  void _toggleGoal(String goal) {
    setState(() {
      if (_primaryGoals.contains(goal)) {
        if (_primaryGoals.length > 1) {
          _primaryGoals.remove(goal);
        }
      } else {
        if (goal == 'Maintain') {
          _primaryGoals = ['Maintain'];
        } else {
          _primaryGoals.remove('Maintain');
          _primaryGoals.add(goal);
        }
      }
    });
  }

  Widget _buildActivityStep(bool isDark) {
    return _buildStepContainer(
      title: 'What is your activity level?',
      subtitle: 'Calculates the multipliers to identify total energy expenditure (TDEE).',
      isDark: isDark,
      content: Column(
        children: [
          _buildChoiceRow('Sedentary', Icons.chair_rounded, _activityLevel == 'Sedentary', () => setState(() => _activityLevel = 'Sedentary'), isDark, description: 'Little to no exercise, desk job'),
          const SizedBox(height: 12),
          _buildChoiceRow('Light', Icons.directions_walk_rounded, _activityLevel == 'Light', () => setState(() => _activityLevel = 'Light'), isDark, description: 'Light exercise or active lifestyle 1-3 days/week'),
          const SizedBox(height: 12),
          _buildChoiceRow('Moderate', Icons.run_circle_outlined, _activityLevel == 'Moderate', () => setState(() => _activityLevel = 'Moderate'), isDark, description: 'Moderate exercise 3-5 days/week'),
          const SizedBox(height: 12),
          _buildChoiceRow('Very active', Icons.bolt_rounded, _activityLevel == 'Very active', () => setState(() => _activityLevel = 'Very active'), isDark, description: 'Intense exercise or athletic job 6-7 days/week'),
        ],
      ),
    );
  }

  Widget _buildDietaryStep(bool isDark) {
    final preferences = ['No restriction', 'Vegetarian', 'Vegan', 'Keto', 'Other'];
    return _buildStepContainer(
      title: 'Any dietary preferences?',
      subtitle: 'Helps curate potential foods and dietary recommendation parameters.',
      isDark: isDark,
      content: Column(
        children: preferences
            .map((pref) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildChoiceRow(pref, Icons.restaurant_menu_rounded, _dietaryPreference == pref, () => setState(() => _dietaryPreference = pref), isDark),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildWorkoutDaysStep(bool isDark) {
    return _buildStepContainer(
      title: 'Workout days per week?',
      subtitle: 'Select how many days you commit to active exercise sessions.',
      isDark: isDark,
      content: Column(
        children: [
          Text(
            '$_workoutDays days',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: FuelixTheme.accentOrange),
          ),
          const SizedBox(height: 30),
          Slider(
            value: _workoutDays.toDouble(),
            min: 0,
            max: 7,
            divisions: 7,
            activeColor: FuelixTheme.accentOrange,
            onChanged: (val) => setState(() => _workoutDays = val.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergiesStep(bool isDark) {
    return _buildStepContainer(
      title: 'Allergies & conditions?',
      subtitle: 'Select any that apply to help us safeguard your meals.',
      isDark: isDark,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allergyTags.map((allergy) {
              final isSelected = _selectedAllergies.contains(allergy);
              return FilterChip(
                label: Text(allergy),
                selected: isSelected,
                selectedColor: FuelixTheme.accentOrange.withOpacity(0.2),
                checkmarkColor: FuelixTheme.accentOrange,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedAllergies.add(allergy);
                    } else {
                      _selectedAllergies.remove(allergy);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _customAllergyController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Add custom allergy (e.g. Peach, Sesame)',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add, color: FuelixTheme.accentOrange),
                onPressed: () {
                  final text = _customAllergyController.text.trim();
                  if (text.isNotEmpty && !_selectedAllergies.contains(text)) {
                    setState(() {
                      _selectedAllergies.add(text);
                      if (!_allergyTags.contains(text)) {
                        _allergyTags.add(text);
                      }
                      _customAllergyController.clear();
                    });
                  }
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: isDark ? FuelixTheme.darkCard : Colors.white,
            ),
            onFieldSubmitted: (text) {
              final val = text.trim();
              if (val.isNotEmpty && !_selectedAllergies.contains(val)) {
                setState(() {
                  _selectedAllergies.add(val);
                  if (!_allergyTags.contains(val)) {
                    _allergyTags.add(val);
                  }
                  _customAllergyController.clear();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // --- SELECTION CARD FOR GENDER ---
  Widget _buildSelectCard(String label, IconData icon, bool isSelected, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: isSelected 
              ? FuelixTheme.accentOrange.withOpacity(0.12)
              : (isDark ? FuelixTheme.darkCard : Colors.white),
          borderRadius: FuelixTheme.cardRadius,
          border: Border.all(
            color: isSelected ? FuelixTheme.accentOrange : Colors.transparent,
            width: 2,
          ),
          boxShadow: FuelixTheme.softShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? FuelixTheme.accentOrange : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? FuelixTheme.accentOrange : (isDark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SELECTION ROW FOR STRINGS ---
  Widget _buildChoiceRow(String title, IconData icon, bool isSelected, VoidCallback onTap, bool isDark, {String? description}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? FuelixTheme.accentOrange.withOpacity(0.1)
              : (isDark ? FuelixTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? FuelixTheme.accentOrange : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: FuelixTheme.softShadow,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? FuelixTheme.accentOrange : (isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? FuelixTheme.accentOrange : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: FuelixTheme.accentOrange, size: 20),
          ],
        ),
      ),
    );
  }

  // --- NEW THEME SELECTION METHODS ---
  Widget _buildThemeStep(bool isDark) {
    final currentMode = ref.watch(themeModeProvider);
    
    return _buildStepContainer(
      title: 'Choose your theme',
      subtitle: 'Personalize your Fuelix experience.',
      isDark: isDark,
      content: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildThemePreviewCard(
                  title: 'Dark Mode',
                  themeMode: ThemeMode.dark,
                  isSelected: currentMode == ThemeMode.dark,
                  cardBg: const Color(0xFF0A0A0F),
                  cardSurface: const Color(0xFF16161D),
                  primaryColor: const Color(0xFF8B5CF6),
                  textColor: const Color(0xFFF2F2F5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildThemePreviewCard(
                  title: 'Light Mode',
                  themeMode: ThemeMode.light,
                  isSelected: currentMode == ThemeMode.light,
                  cardBg: const Color(0xFFFAFAFC),
                  cardSurface: const Color(0xFFFFFFFF),
                  primaryColor: const Color(0xFF6D28D9),
                  textColor: const Color(0xFF111114),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: currentMode == ThemeMode.system
                    ? FuelixTheme.accentOrange.withOpacity(0.12)
                    : (isDark ? FuelixTheme.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: currentMode == ThemeMode.system
                      ? FuelixTheme.accentOrange
                      : (isDark ? Colors.white10 : Colors.black12),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_suggest_rounded,
                    color: currentMode == ThemeMode.system
                        ? FuelixTheme.accentOrange
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Match my device',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: currentMode == ThemeMode.system
                                ? FuelixTheme.accentOrange
                                : (isDark ? Colors.white : Colors.black),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Auto-follows system settings',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (currentMode == ThemeMode.system)
                    const Icon(Icons.check_circle_rounded, color: FuelixTheme.accentOrange),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreviewCard({
    required String title,
    required ThemeMode themeMode,
    required bool isSelected,
    required Color cardBg,
    required Color cardSurface,
    required Color primaryColor,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(themeMode),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: isSelected
              ? FuelixTheme.accentOrange.withOpacity(0.12)
              : (themeMode == ThemeMode.dark ? Colors.grey[900] : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? FuelixTheme.accentOrange : Colors.transparent,
            width: 2,
          ),
          boxShadow: FuelixTheme.softShadow,
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 30, height: 6, color: textColor.withOpacity(0.2)),
                        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: primaryColor.withOpacity(0.6))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryColor, width: 4),
                        ),
                        child: Center(
                          child: Container(
                            width: 14,
                            height: 6,
                            color: textColor.withOpacity(0.15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(width: double.infinity, height: 4, color: cardSurface),
                    const SizedBox(height: 4),
                    Container(width: 24, height: 4, color: cardSurface),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? FuelixTheme.accentOrange : (themeMode == ThemeMode.dark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietStrictnessStep(bool isDark) {
    return _buildStepContainer(
      title: 'Choose your diet plan type',
      subtitle: 'Strict targets demand higher precision, while moderate targets allow more flexibility.',
      isDark: isDark,
      content: Row(
        children: [
          Expanded(
            child: _buildSelectCard(
              'Moderate',
              Icons.track_changes_rounded,
              _dietStrictness == 'Moderate',
              () => setState(() => _dietStrictness = 'Moderate'),
              isDark,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSelectCard(
              'Strict',
              Icons.timer_rounded,
              _dietStrictness == 'Strict',
              () => setState(() => _dietStrictness = 'Strict'),
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGymActiveStep(bool isDark) {
    return _buildStepContainer(
      title: 'Are you active in the gym?',
      subtitle: 'Gym strength training demands higher protein splits to repair muscle tissue.',
      isDark: isDark,
      content: Row(
        children: [
          Expanded(
            child: _buildSelectCard(
              'Home/Outdoor\nWorkouts',
              Icons.home_rounded,
              !_isGymActive,
              () => setState(() => _isGymActive = false),
              isDark,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSelectCard(
              'Gym Strength\nTraining',
              Icons.fitness_center_rounded,
              _isGymActive,
              () => setState(() => _isGymActive = true),
              isDark,
            ),
          ),
        ],
      ),
    );
  }
}

// --- ONBOARDING LOADING SCREEN OVERLAY ---
class OnboardingLoadingScreen extends StatelessWidget {
  const OnboardingLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing
      child: Scaffold(
        backgroundColor: (isDark ? FuelixTheme.darkBg : FuelixTheme.lightBg).withOpacity(0.95),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Visual custom loader
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: FuelixTheme.accentOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(FuelixTheme.accentOrange),
                      ),
                    ),
                    Icon(
                      Icons.insights_rounded,
                      size: 40,
                      color: FuelixTheme.accentOrange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Building your plan...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : FuelixTheme.textDarkPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Computing BMR, daily caloric deficits, and macro splits optimized for your body profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
