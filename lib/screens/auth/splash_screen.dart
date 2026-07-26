import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../models/user_profile.dart';
import '../../utils/theme.dart';
import '../dashboard_shell.dart';
import '../onboarding/onboarding_wizard.dart';
import 'login_screen.dart';
import 'email_verification_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    _navigateToNext();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateToNext() async {
    // Wait for the animation and a short delay
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Read the current auth state
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;

    if (user != null) {
      if (!user.isEmailVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
        );
        return;
      }

      // Check if we have a local cached profile first to avoid blocking startup
      final profileBox = ref.read(profileBoxProvider);
      final localData = profileBox.get(user.uid);
      
      if (localData != null) {
        final cachedProfile = UserProfile.fromMap(Map<String, dynamic>.from(localData as Map));
        // Set the state synchronously so provider is ready
        ref.read(userProfileProvider.notifier).state = cachedProfile;
        
        // Trigger background refresh of the profile from Supabase
        ref.read(userProfileProvider.notifier).loadProfile(user.uid, user.email, user.name);

        if (cachedProfile.isOnboarded) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardShell()),
          );
          return;
        }
      }

      // If no cache exists, load profile (waiting for it)
      await ref.read(userProfileProvider.notifier).loadProfile(user.uid, user.email, user.name);
      final profile = ref.read(userProfileProvider);
      
      if (profile != null && profile.isOnboarded) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardShell()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingWizard()),
        );
      }
    } else {
      // Not logged in
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? FuelixTheme.darkBg : FuelixTheme.lightBg,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: FuelixTheme.accentOrange,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: FuelixTheme.accentOrange.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 55,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              // App name
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Fuel',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : FuelixTheme.textDarkPrimary,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const Text(
                    'ix',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: FuelixTheme.accentOrange,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                'AI FITNESS & NUTRITION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(FuelixTheme.accentOrange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
