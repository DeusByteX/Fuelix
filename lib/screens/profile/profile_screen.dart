import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  bool _isEditing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _initFields(UserProfile profile) {
    _nameController.text = profile.name;
    _ageController.text = profile.age.toString();
    
    final displayWeight = profile.isMetric ? profile.weightKg : profile.weightKg * 2.20462;
    _weightController.text = displayWeight.toStringAsFixed(1);

    final displayTargetWeight = profile.isMetric ? profile.targetWeightKg : profile.targetWeightKg * 2.20462;
    _targetWeightController.text = displayTargetWeight.toStringAsFixed(1);

    final displayHeight = profile.isMetric ? profile.heightCm : profile.heightCm / 30.48; // In feet for simple text
    _heightController.text = displayHeight.toStringAsFixed(1);
  }

  Future<void> _saveProfileChanges(UserProfile currentProfile) async {
    final ageVal = int.tryParse(_ageController.text) ?? currentProfile.age;
    final wVal = double.tryParse(_weightController.text) ?? currentProfile.weightKg;
    final twVal = double.tryParse(_targetWeightController.text) ?? currentProfile.targetWeightKg;
    final hVal = double.tryParse(_heightController.text) ?? currentProfile.heightCm;

    // Convert from Imperial back to Metric if unit is Imperial
    final weightKg = currentProfile.isMetric ? wVal : wVal / 2.20462;
    final targetWeightKg = currentProfile.isMetric ? twVal : twVal / 2.20462;
    final heightCm = currentProfile.isMetric ? hVal : hVal * 30.48;

    final updated = currentProfile.copyWith(
      name: _nameController.text.trim(),
      age: ageVal,
      weightKg: weightKg,
      targetWeightKg: targetWeightKg,
      heightCm: heightCm,
    );

    await ref.read(userProfileProvider.notifier).saveProfile(updated);
    setState(() => _isEditing = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully! Calorie/Macro splits recalculated.'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _updateMetricToggle(UserProfile profile, bool isMetric) async {
    final updated = profile.copyWith(isMetric: isMetric);
    await ref.read(userProfileProvider.notifier).saveProfile(updated);
    _initFields(updated);
  }

  Future<void> _updateDropdownField(UserProfile profile, {List<String>? goals, String? activity, String? dietary}) async {
    final updated = profile.copyWith(
      primaryGoals: goals,
      activityLevel: activity,
      dietaryPreference: dietary,
    );
    await ref.read(userProfileProvider.notifier).saveProfile(updated);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calorie target and macro goals recalculated!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _updateThemeOnProfile(UserProfile profile, String themePref) async {
    final updated = profile.copyWith(themePreference: themePref);
    await ref.read(userProfileProvider.notifier).saveProfile(updated);
  }

  Future<void> _updateStrictnessAndGym(UserProfile profile, {String? strictness, bool? gymActive}) async {
    final updated = profile.copyWith(
      dietStrictness: strictness,
      isGymActive: gymActive,
    );
    await ref.read(userProfileProvider.notifier).saveProfile(updated);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diet plan and macro targets recalculated!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _signOut() async {
    final auth = ref.read(authServiceProvider);
    await auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(userProfileProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isEditing) {
      _initFields(profile);
    }

    final weightUnit = profile.isMetric ? 'kg' : 'lbs';
    final heightUnit = profile.isMetric ? 'cm' : 'ft';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check_circle_rounded : Icons.edit_rounded, color: FuelixTheme.accentOrange),
            onPressed: () {
              if (_isEditing) {
                _saveProfileChanges(profile);
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Header Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? FuelixTheme.darkCard : Colors.white,
                  borderRadius: FuelixTheme.cardRadius,
                  boxShadow: FuelixTheme.softShadow,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: FuelixTheme.accentOrange.withOpacity(0.1),
                      child: Text(
                        profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 28, color: FuelixTheme.accentOrange, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isEditing)
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4)),
                            )
                          else
                            Text(
                              profile.name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            profile.email,
                            style: TextStyle(color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Target Calories/Macros Panel
              const Text('Target Goals Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? FuelixTheme.darkCard : Colors.white,
                  borderRadius: FuelixTheme.cardRadius,
                  boxShadow: FuelixTheme.softShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildGoalMetric('kcal', profile.dailyCalorieTarget, FuelixTheme.accentOrange),
                    _buildGoalMetric('Carbs', profile.dailyCarbsTarget, FuelixTheme.accentOrange),
                    _buildGoalMetric('Protein', profile.dailyProteinTarget, FuelixTheme.accentLime),
                    _buildGoalMetric('Fat', profile.dailyFatTarget, const Color(0xFF00C2FF)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. User Parameters (Editable Fields)
              const Text('Physical Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    _buildPreferenceItem(
                      'Unit System',
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChoiceChip(
                            label: const Text('Metric'),
                            selected: profile.isMetric,
                            selectedColor: FuelixTheme.accentOrange.withOpacity(0.15),
                            checkmarkColor: FuelixTheme.accentOrange,
                            onSelected: (selected) => _updateMetricToggle(profile, true),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Imperial'),
                            selected: !profile.isMetric,
                            selectedColor: FuelixTheme.accentOrange.withOpacity(0.15),
                            checkmarkColor: FuelixTheme.accentOrange,
                            onSelected: (selected) => _updateMetricToggle(profile, false),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),
                    _buildProfileInputField('Age', _ageController, 'years', _isEditing, isDark),
                    const Divider(height: 24),
                    _buildProfileInputField('Height', _heightController, heightUnit, _isEditing, isDark),
                    const Divider(height: 24),
                    _buildProfileInputField('Weight', _weightController, weightUnit, _isEditing, isDark),
                    const Divider(height: 24),
                    _buildProfileInputField('Target Weight', _targetWeightController, weightUnit, _isEditing, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Dropdown Goals Settings Card
              const Text('Program Configurations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? FuelixTheme.darkCard : Colors.white,
                  borderRadius: FuelixTheme.cardRadius,
                  boxShadow: FuelixTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Primary Goals', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('(Multi-Select)', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Lose weight', 'Build muscle', 'Maintain', 'Improve endurance'].map((goal) {
                        final isSelected = profile.primaryGoals.contains(goal);
                        return FilterChip(
                          label: Text(goal),
                          selected: isSelected,
                          selectedColor: FuelixTheme.accentOrange.withOpacity(0.15),
                          checkmarkColor: FuelixTheme.accentOrange,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? FuelixTheme.accentOrange : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          onSelected: (selected) {
                            final List<String> currentGoals = List<String>.from(profile.primaryGoals);
                            if (selected) {
                              if (goal == 'Maintain') {
                                _updateDropdownField(profile, goals: ['Maintain']);
                              } else {
                                currentGoals.remove('Maintain');
                                if (!currentGoals.contains(goal)) {
                                  currentGoals.add(goal);
                                }
                                _updateDropdownField(profile, goals: currentGoals);
                              }
                            } else {
                              if (currentGoals.length > 1) {
                                currentGoals.remove(goal);
                                _updateDropdownField(profile, goals: currentGoals);
                              }
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const Divider(height: 24),
                    _buildDropdownItem(
                      'Activity Level',
                      profile.activityLevel,
                      ['Sedentary', 'Light', 'Moderate', 'Very active'],
                      (val) => _updateDropdownField(profile, activity: val),
                    ),
                    const Divider(height: 24),
                    _buildDropdownItem(
                      'Diet Preference',
                      profile.dietaryPreference,
                      ['No restriction', 'Vegetarian', 'Vegan', 'Keto', 'Other'],
                      (val) => _updateDropdownField(profile, dietary: val),
                    ),
                    const Divider(height: 24),
                    _buildPreferenceItem(
                      'Diet Plan Strictness',
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChoiceChip(
                            label: const Text('Moderate'),
                            selected: profile.dietStrictness == 'Moderate',
                            selectedColor: FuelixTheme.accentOrange.withOpacity(0.15),
                            checkmarkColor: FuelixTheme.accentOrange,
                            onSelected: (selected) {
                              if (selected) {
                                _updateStrictnessAndGym(profile, strictness: 'Moderate');
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Strict'),
                            selected: profile.dietStrictness == 'Strict',
                            selectedColor: FuelixTheme.accentOrange.withOpacity(0.15),
                            checkmarkColor: FuelixTheme.accentOrange,
                            onSelected: (selected) {
                              if (selected) {
                                _updateStrictnessAndGym(profile, strictness: 'Strict');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),
                    _buildPreferenceItem(
                      'Gym Strength Active',
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChoiceChip(
                            label: const Text('No (Home/Out)'),
                            selected: !profile.isGymActive,
                            selectedColor: FuelixTheme.accentOrange.withOpacity(0.15),
                            checkmarkColor: FuelixTheme.accentOrange,
                            onSelected: (selected) {
                              if (selected) {
                                _updateStrictnessAndGym(profile, gymActive: false);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Yes (Active Gym)'),
                            selected: profile.isGymActive,
                            selectedColor: FuelixTheme.accentOrange.withOpacity(0.15),
                            checkmarkColor: FuelixTheme.accentOrange,
                            onSelected: (selected) {
                              if (selected) {
                                _updateStrictnessAndGym(profile, gymActive: true);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Appearance settings Card
              const Text('Appearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? FuelixTheme.darkCard : Colors.white,
                  borderRadius: FuelixTheme.cardRadius,
                  boxShadow: FuelixTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreferenceItem(
                      'Theme Mode',
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChoiceChip(
                            label: const Text('Light'),
                            selected: ref.watch(themeModeProvider) == ThemeMode.light,
                            selectedColor: FuelixTheme.accentOrange.withOpacity(0.15),
                            checkmarkColor: FuelixTheme.accentOrange,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                                _updateThemeOnProfile(profile, 'light');
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Dark'),
                            selected: ref.watch(themeModeProvider) == ThemeMode.dark,
                            selectedColor: FuelixTheme.accentOrange.withOpacity(0.15),
                            checkmarkColor: FuelixTheme.accentOrange,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                                _updateThemeOnProfile(profile, 'dark');
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('System'),
                            selected: ref.watch(themeModeProvider) == ThemeMode.system,
                            selectedColor: FuelixTheme.accentOrange.withOpacity(0.15),
                            checkmarkColor: FuelixTheme.accentOrange,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                                _updateThemeOnProfile(profile, 'system');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // 5. Logout Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _signOut,
                  child: const Text('Log Out Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalMetric(String label, int val, Color color) {
    return Column(
      children: [
        Text(val.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPreferenceItem(String label, Widget trailing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        trailing,
      ],
    );
  }

  Widget _buildProfileInputField(String label, TextEditingController controller, String unit, bool isEditing, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEditing)
              SizedBox(
                width: 70,
                height: 38,
                child: TextFormField(
                  controller: controller,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                ),
              )
            else
              Text(controller.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(width: 6),
            Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownItem(String label, String value, List<String> options, Function(String?) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox.shrink(),
          onChanged: onChanged,
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))))
              .toList(),
        ),
      ],
    );
  }
}
