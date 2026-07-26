import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FuelixUser {
  final String uid;
  final String email;
  final String name;
  final bool isEmailVerified;

  FuelixUser({
    required this.uid,
    required this.email,
    required this.name,
    this.isEmailVerified = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'isEmailVerified': isEmailVerified,
    };
  }

  factory FuelixUser.fromMap(Map<dynamic, dynamic> map) {
    return FuelixUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      isEmailVerified: map['isEmailVerified'] ?? true,
    );
  }
}

class AuthService {
  final Box _localBox;
  bool _useSupabase = false;
  
  final _userController = StreamController<FuelixUser?>.broadcast();
  FuelixUser? _currentUser;
  StreamSubscription? _supabaseSubscription;

  AuthService(this._localBox) {
    _init();
  }

  void _init() {
    try {
      // Check if Supabase client is initialized
      final client = Supabase.instance.client;
      _useSupabase = true;
      
      // Preload cached user session synchronously for instant startup routing
      final cached = _localBox.get('current_user');
      if (cached != null) {
        _currentUser = FuelixUser.fromMap(cached as Map);
        _userController.add(_currentUser);
      }
      
      // Listen to Supabase auth state changes
      _supabaseSubscription = client.auth.onAuthStateChange.listen((data) {
        final user = data.session?.user;
        if (user != null) {
          final localUser = FuelixUser(
            uid: user.id,
            email: user.email ?? '',
            name: user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'User',
            isEmailVerified: user.emailConfirmedAt != null,
          );
          _currentUser = localUser;
          _userController.add(localUser);
          _localBox.put('current_user', localUser.toMap());
        } else {
          _currentUser = null;
          _userController.add(null);
          _localBox.delete('current_user');
        }
      });
      debugPrint("AuthService initialized successfully with Supabase");
    } catch (e) {
      debugPrint("AuthService failed to initialize Supabase, falling back to Hive: $e");
      _setupLocalSession();
    }
  }

  void _setupLocalSession() {
    _useSupabase = false;
    final cached = _localBox.get('current_user');
    if (cached != null) {
      _currentUser = FuelixUser.fromMap(cached as Map);
      _userController.add(_currentUser);
    } else {
      _currentUser = null;
      _userController.add(null);
    }
    debugPrint("AuthService initialized using local Hive session");
  }

  // Stream of auth changes
  Stream<FuelixUser?> get authStateChanges => _userController.stream;

  // Sync getter for current user
  FuelixUser? get currentUser => _currentUser;

  bool get isSupabaseEnabled => _useSupabase;

  // Sign up with Email/Password
  Future<FuelixUser> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    if (_useSupabase) {
      try {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name},
        );
        
        final user = response.user;
        if (user != null) {
          final localUser = FuelixUser(
            uid: user.id,
            email: user.email ?? email,
            name: name,
            isEmailVerified: user.emailConfirmedAt != null,
          );
          _currentUser = localUser;
          await _localBox.put('current_user', localUser.toMap());
          await _localBox.put('remembered_email', email);
          _userController.add(localUser);
          return localUser;
        }
        throw Exception("Failed to retrieve user credentials from Supabase.");
      } catch (e) {
        debugPrint("Supabase Sign Up Error: $e");
        rethrow;
      }
    } else {
      // Local Database mock registration
      final uid = 'local_user_${DateTime.now().millisecondsSinceEpoch}';
      final usersMap = _localBox.get('local_registered_users', defaultValue: {}) as Map;
      
      if (usersMap.containsKey(email)) {
        throw Exception("The email address is already in use by another account.");
      }
      
      final newUserMap = {'uid': uid, 'email': email, 'name': name, 'password': password};
      usersMap[email] = newUserMap;
      await _localBox.put('local_registered_users', usersMap);

      final user = FuelixUser(uid: uid, email: email, name: name, isEmailVerified: true);
      _currentUser = user;
      await _localBox.put('current_user', user.toMap());
      await _localBox.put('remembered_email', email);
      _userController.add(user);
      return user;
    }
  }

  // Sign in with Email/Password
  Future<FuelixUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_useSupabase) {
      try {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        final user = response.user;
        if (user != null) {
          final localUser = FuelixUser(
            uid: user.id,
            email: user.email ?? email,
            name: user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'User',
            isEmailVerified: user.emailConfirmedAt != null,
          );
          _currentUser = localUser;
          await _localBox.put('current_user', localUser.toMap());
          await _localBox.put('remembered_email', email);
          _userController.add(localUser);
          return localUser;
        }
        throw Exception("Failed to login: User not found");
      } catch (e) {
        debugPrint("Supabase Sign In Error: $e");
        rethrow;
      }
    } else {
      // Local authentication lookup
      final usersMap = _localBox.get('local_registered_users', defaultValue: {}) as Map;
      if (!usersMap.containsKey(email) || usersMap[email]['password'] != password) {
        throw Exception("Invalid email or password.");
      }
      
      final name = usersMap[email]['name'] ?? 'User';
      final uid = usersMap[email]['uid'] ?? 'local_user';
      
      final user = FuelixUser(uid: uid, email: email, name: name, isEmailVerified: true);
      _currentUser = user;
      await _localBox.put('current_user', user.toMap());
      await _localBox.put('remembered_email', email);
      _userController.add(user);
      return user;
    }
  }

  // Google Sign-In
  Future<FuelixUser?> signInWithGoogle() async {
    if (_useSupabase) {
      try {
        // Trigger OAuth login in Supabase
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
        );
        // Returns null because the user will be authenticated asynchronously via the redirect callback
        return null;
      } catch (e) {
        debugPrint("Supabase Google Auth Error: $e");
        rethrow;
      }
    } else {
      final user = FuelixUser(
        uid: 'google_local_${DateTime.now().millisecondsSinceEpoch}',
        email: 'google.local@fuelix.com',
        name: 'Google Local User',
        isEmailVerified: true,
      );
      _currentUser = user;
      await _localBox.put('current_user', user.toMap());
      _userController.add(user);
      return user;
    }
  }

  // Apple Sign-In
  Future<FuelixUser> signInWithApple() async {
    if (_useSupabase) {
      try {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.apple,
        );
        return FuelixUser(
          uid: 'apple_oauth_session',
          email: 'apple.auth@supabase.com',
          name: 'OAuth User',
          isEmailVerified: true,
        );
      } catch (e) {
        debugPrint("Supabase Apple Auth Error: $e");
        rethrow;
      }
    } else {
      final user = FuelixUser(
        uid: 'apple_user_${DateTime.now().millisecondsSinceEpoch}',
        email: 'apple.user@fuelix.com',
        name: 'Apple User',
        isEmailVerified: true,
      );
      _currentUser = user;
      await _localBox.put('current_user', user.toMap());
      _userController.add(user);
      return user;
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (_useSupabase) {
      await Supabase.instance.client.auth.signOut();
    }
    _currentUser = null;
    await _localBox.delete('current_user');
    _userController.add(null);
  }

  void dispose() {
    _supabaseSubscription?.cancel();
    _userController.close();
  }

  String? getRememberedEmail() {
    return _localBox.get('remembered_email') as String?;
  }

  Future<FuelixUser?> refreshSession() async {
    if (_useSupabase) {
      try {
        final response = await Supabase.instance.client.auth.refreshSession();
        final user = response.user;
        if (user != null) {
          final localUser = FuelixUser(
            uid: user.id,
            email: user.email ?? '',
            name: user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'User',
            isEmailVerified: user.emailConfirmedAt != null,
          );
          _currentUser = localUser;
          await _localBox.put('current_user', localUser.toMap());
          _userController.add(localUser);
          return localUser;
        }
      } catch (e) {
        debugPrint("Error refreshing Supabase session: $e");
      }
    }
    return _currentUser;
  }

  Future<void> resendVerificationEmail(String email) async {
    if (_useSupabase) {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    }
  }
}
