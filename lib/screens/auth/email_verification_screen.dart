import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import '../dashboard_shell.dart';
import '../onboarding/onboarding_wizard.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      final auth = ref.read(authServiceProvider);
      final user = await auth.refreshSession();
      
      if (user != null && user.isEmailVerified) {
        // Load user profile
        final db = ref.read(databaseServiceProvider);
        final profile = await db.getUserProfile(user.uid);
        await ref.read(userProfileProvider.notifier).loadProfile(user.uid, user.email, user.name);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email verified successfully!'), backgroundColor: Colors.green),
          );
          if (profile != null && profile.isOnboarded) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardShell()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const OnboardingWizard()),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification pending. Please verify your email first.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _resendEmail() async {
    final auth = ref.read(authServiceProvider);
    final email = auth.currentUser?.email;
    if (email == null) return;

    setState(() => _isResending = true);
    try {
      await auth.resendVerificationEmail(email);
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification link resent successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).value;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: isDark ? FuelixTheme.darkBg : FuelixTheme.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon envelope design
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: FuelixTheme.accentOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  size: 50,
                  color: FuelixTheme.accentOrange,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : FuelixTheme.textDarkPrimary,
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'We have sent a verification link to\n',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: email,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : FuelixTheme.textDarkPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Please click the link in that email to confirm your account and continue your journey.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? FuelixTheme.textLightSecondary.withOpacity(0.8) : FuelixTheme.textDarkSecondary.withOpacity(0.8),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkVerification,
                  child: _isChecking
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('I Have Verified'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: isDark ? FuelixTheme.darkCard : Colors.grey[300]!),
                  ),
                  onPressed: (_cooldownSeconds > 0 || _isResending) ? null : _resendEmail,
                  child: _isResending
                      ? const CircularProgressIndicator()
                      : Text(_cooldownSeconds > 0
                          ? 'Resend in ${_cooldownSeconds}s'
                          : 'Resend Verification Email'),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _logout,
                child: const Text(
                  'Cancel & Log Out',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
