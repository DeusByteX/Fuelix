import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/splash_screen.dart';
import 'utils/theme.dart';
import 'providers/providers.dart';

void main() async {
  // Ensure Flutter engine is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load Environment configs (.env)
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("Dotenv configurations loaded successfully.");
  } catch (e) {
    debugPrint("Warning: Could not load .env file, continuing with default mock settings. Error: $e");
  }

  // Initialize Local Hive databases
  try {
    await Hive.initFlutter();
    
    // Open caching storage boxes
    await Hive.openBox('fuelix_auth');
    await Hive.openBox('fuelix_profiles');
    await Hive.openBox('fuelix_meal_logs');
    await Hive.openBox('fuelix_workouts');
    await Hive.openBox('fuelix_weights');
    
    debugPrint("Local Hive boxes initialized successfully.");
  } catch (e) {
    debugPrint("Critical Error: Hive database failed to initialize: $e");
  }


  // Safe initialize Supabase
  try {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (url.isNotEmpty && anonKey.isNotEmpty) {
      await Supabase.initialize(url: url, anonKey: anonKey);
      debugPrint("Supabase initialized successfully.");
    }
  } catch (e) {
    debugPrint("Supabase failed to initialize: $e");
  }

  runApp(
    const ProviderScope(
      child: FuelixApp(),
    ),
  );
}

class FuelixApp extends ConsumerWidget {
  const FuelixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Fuelix - AI Fitness & Nutrition',
      debugShowCheckedModeBanner: false,
      theme: FuelixTheme.lightTheme,
      darkTheme: FuelixTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
      builder: (context, child) {
        return SecurityOverlay(child: child!);
      },
    );
  }
}

// --- PRIVACY SHIELD FOR BACKGROUND TRANSITIONS ---
class SecurityOverlay extends StatefulWidget {
  final Widget child;
  const SecurityOverlay({super.key, required this.child});

  @override
  State<SecurityOverlay> createState() => _SecurityOverlayState();
}

class _SecurityOverlayState extends State<SecurityOverlay> with WidgetsBindingObserver {
  bool _isBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isBackgrounded = state == AppLifecycleState.paused || state == AppLifecycleState.inactive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isBackgrounded)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0A0A0F),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5A36).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.security_rounded,
                        color: Color(0xFFFF5A36),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fuelix Secure Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Screen contents hidden for privacy',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
