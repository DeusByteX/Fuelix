import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../providers/providers.dart';
import '../../models/user_profile.dart';
import '../../utils/theme.dart';
import '../dashboard_shell.dart';
import '../onboarding/onboarding_wizard.dart';
import 'email_verification_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    final remembered = ref.read(authServiceProvider).getRememberedEmail();
    if (remembered != null) {
      _emailController.text = remembered;
    }
    
    // Listen for authentication changes to route dynamically
    _authSubscription = ref.read(authServiceProvider).authStateChanges.listen((user) async {
      if (user != null && mounted) {
        setState(() => _isLoading = true);
        
        if (!user.isEmailVerified) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
            );
          }
          return;
        }
        
        // Check local cache first to avoid blocking transitions
        final profileBox = ref.read(profileBoxProvider);
        final localData = profileBox.get(user.uid);
        
        if (localData != null) {
          final cachedProfile = UserProfile.fromMap(Map<String, dynamic>.from(localData as Map));
          ref.read(userProfileProvider.notifier).state = cachedProfile;
          ref.read(userProfileProvider.notifier).loadProfile(user.uid, user.email, user.name);
          
          if (mounted) {
            if (cachedProfile.isOnboarded) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardShell()),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const OnboardingWizard()),
              );
            }
            return;
          }
        }
        
        await ref.read(userProfileProvider.notifier).loadProfile(user.uid, user.email, user.name);
        final profile = ref.read(userProfileProvider);
        
        if (mounted) {
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
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When the user returns to the app from the external browser,
      // if it is still loading and the user remains unauthenticated,
      // turn off the loading spinner.
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isLoading && ref.read(authServiceProvider).currentUser == null) {
          setState(() => _isLoading = false);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(authServiceProvider);
      if (_isSignUp) {
        final user = await auth.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
        );
        
        if (user.isEmailVerified) {
          await ref.read(userProfileProvider.notifier).loadProfile(user.uid, user.email, user.name);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const OnboardingWizard()),
            );
          }
        } else {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
            );
          }
        }
      } else {
        final user = await auth.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!user.isEmailVerified) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
            );
          }
          return;
        }

        // Check local cache first to avoid blocking transitions
        final profileBox = ref.read(profileBoxProvider);
        final localData = profileBox.get(user.uid);
        
        if (localData != null) {
          final cachedProfile = UserProfile.fromMap(Map<String, dynamic>.from(localData as Map));
          ref.read(userProfileProvider.notifier).state = cachedProfile;
          ref.read(userProfileProvider.notifier).loadProfile(user.uid, user.email, user.name);
          
          if (mounted) {
            if (cachedProfile.isOnboarded) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardShell()),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const OnboardingWizard()),
              );
            }
            return;
          }
        }

        await ref.read(userProfileProvider.notifier).loadProfile(user.uid, user.email, user.name);
        final profile = ref.read(userProfileProvider);

        if (mounted) {
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
      }
    } catch (e) {
      setState(() {
        _errorMessage = _cleanErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      // Note: If using mock, the authStateChanges listener will handle routing.
      // If using Supabase, it launches the browser, and the listener will handle routing when they successfully log in.
    } catch (e) {
      setState(() {
        _errorMessage = _cleanErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  String _cleanErrorMessage(dynamic error) {
    final errStr = error.toString();
    
    if (errStr.contains('invalid_credentials') || errStr.contains('Invalid login credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (errStr.contains('email_already_exists') || errStr.contains('already registered') || errStr.contains('already exists')) {
      return 'This email is already registered. Try logging in instead.';
    }
    if (errStr.contains('network') || errStr.contains('SocketException') || errStr.contains('Failed host lookup')) {
      return 'Connection failed. Please check your internet connection and try again.';
    }
    if (errStr.contains('weak_password') || errStr.contains('Password should be')) {
      return 'Password is too weak. Make sure it is at least 6 characters.';
    }
    if (errStr.contains('User not found')) {
      return 'No account found with this email. Please sign up.';
    }
    if (errStr.contains('Too many requests') || errStr.contains('rate limit')) {
      return 'Too many login attempts. Please try again in a few minutes.';
    }
    
    // Parse Supabase AuthException / AuthApiException message fields if present
    final messageRegex = RegExp(r'message:\s*([^,)]+)');
    final match = messageRegex.firstMatch(errStr);
    if (match != null) {
      final coreMessage = match.group(1)?.trim();
      if (coreMessage != null && coreMessage.isNotEmpty) {
        return coreMessage[0].toUpperCase() + coreMessage.substring(1);
      }
    }

    var clean = errStr
        .replaceFirst('Exception: ', '')
        .replaceFirst('AuthException: ', '')
        .replaceFirst('AuthApiException: ', '');
    if (clean.contains('(')) {
      return 'An unexpected authentication error occurred. Please try again.';
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // App Brand Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FuelixTheme.accentOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      Text(
                        'Fuel',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : FuelixTheme.textDarkPrimary,
                        ),
                      ),
                      const Text(
                        'ix',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: FuelixTheme.accentOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // Welcome text
              Text(
                _isSignUp ? 'Create your account' : 'Welcome back',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : FuelixTheme.textDarkPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp 
                    ? 'Track workouts, scan meals, and reach your goals.' 
                    : 'Log in to continue your personalized health journey.',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary,
                ),
              ),
              const SizedBox(height: 36),

              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Enter your name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: isDark ? FuelixTheme.darkCard : Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'name@example.com',
                        prefixIcon: const Icon(Icons.mail_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: isDark ? FuelixTheme.darkCard : Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: isDark ? FuelixTheme.darkCard : Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (_isSignUp) {
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          if (!value.contains(RegExp(r'[A-Z]'))) {
                            return 'Password must contain at least one uppercase letter';
                          }
                          if (!value.contains(RegExp(r'[a-z]'))) {
                            return 'Password must contain at least one lowercase letter';
                          }
                          if (!value.contains(RegExp(r'[0-9]'))) {
                            return 'Password must contain at least one number';
                          }
                          if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                            return 'Password must contain at least one special character';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(_isSignUp ? 'Create Account' : 'Log In'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              
              // Mode Switcher
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                      _errorMessage = null;
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      text: _isSignUp ? 'Already have an account? ' : 'New to Fuelix? ',
                      style: TextStyle(color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary, fontSize: 14),
                      children: [
                        TextSpan(
                          text: _isSignUp ? 'Log In' : 'Sign Up',
                          style: const TextStyle(
                            color: FuelixTheme.accentOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
              
              Row(
                children: [
                  Expanded(child: Divider(color: isDark ? FuelixTheme.darkCard : Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR CONTINUE WITH', style: TextStyle(fontSize: 12, color: isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary, letterSpacing: 1.0)),
                  ),
                  Expanded(child: Divider(color: isDark ? FuelixTheme.darkCard : Colors.grey[300])),
                ],
              ),

              const SizedBox(height: 24),

              // Social logins
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: isDark ? FuelixTheme.darkCard : Colors.grey[300]!),
                  ),
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 30, color: Colors.redAccent),
                  label: Text('Continue with Google', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
