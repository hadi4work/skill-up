import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final PushNotificationService? _pushNotificationService;

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<UserModel?>? _userProfileSubscription;

  AuthProvider() : _pushNotificationService = Platform.isAndroid ? PushNotificationService() : null {
    _init();
  }

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  /// المستخدم مسجّل دخوله في Firebase لكن لم يختر نوع الحساب بعد (مثلاً بعد تسجيل الدخول بـ Google لأول مرة).
  bool get needsAccountTypeSelection {
    User? fb = _authService.currentUser;
    if (fb == null) return false;
    return _user == null || (_user!.accountType.isEmpty);
  }

  User? get firebaseUser => _authService.currentUser;

  // Initialize and check auth state
  Future<void> _init() async {
    // Check current user immediately
    User? currentUser = _authService.currentUser;
    if (currentUser != null) {
      await _loadUserProfile(currentUser.uid);
      // Listen to user profile changes in Firestore for real-time updates
      _listenToUserProfileChanges(currentUser.uid);
    }
    
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        await _loadUserProfile(firebaseUser.uid);
        // Listen to user profile changes in Firestore for real-time updates
        _listenToUserProfileChanges(firebaseUser.uid);
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }

  // Listen to user profile changes in Firestore for real-time XP/Level updates
  void _listenToUserProfileChanges(String uid) {
    // Cancel previous subscription if exists
    _userProfileSubscription?.cancel();
    
    // Start listening to user profile changes
    _userProfileSubscription = _userService.getUserProfileStream(uid).listen(
      (UserModel? updatedUser) {
        if (updatedUser != null) {
          debugPrint('🔄 Stream update received for user ${updatedUser.uid}');
          debugPrint('   XP: ${updatedUser.xp}, Level: ${updatedUser.level}');
          
          // Recalculate level from XP to ensure it's always correct
          int correctLevel = updatedUser.calculateLevel(updatedUser.xp);
          if (updatedUser.level != correctLevel) {
            debugPrint('   ⚠️ Level mismatch! Correcting level from ${updatedUser.level} to $correctLevel');
            updatedUser = updatedUser.copyWith(level: correctLevel);
          }
          
          // Always update user data from stream
          _user = updatedUser;
          notifyListeners();
          
          debugPrint('✅ User profile updated via stream');
        } else {
          debugPrint('⚠️ Stream returned null user');
        }
      },
      onError: (error) {
        debugPrint('❌ Stream error: $error');
      },
    );
    
    debugPrint('👂 Started listening to user profile changes for $uid');
  }

  // Load user profile from Firestore
  Future<void> _loadUserProfile(String uid) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      UserModel? userProfile = await _userService.getUserProfile(uid);
      if (userProfile != null) {
        _user = userProfile;
        debugPrint('User loaded: ${userProfile.name}, Type: ${userProfile.accountType}');
        await _saveAuthState(true);
      } else {
        debugPrint('User profile not found for uid: $uid');
        _user = null;
        await _saveAuthState(false);
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      _errorMessage = e.toString();
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign up with email and password
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String accountType,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint('🚀 Starting sign up process...');
      debugPrint('   Name: $name');
      debugPrint('   Email: $email');
      debugPrint('   Account Type: $accountType');

      // Create auth user
      UserCredential? userCredential;
      try {
        userCredential = await _authService.signUpWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint('✅ Auth user created successfully');
      } catch (e) {
        debugPrint('❌ Error creating auth user: $e');
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (userCredential?.user != null) {
        final uid = userCredential!.user!.uid;
        debugPrint('   User UID: $uid');
        
        // Create user profile in Firestore
        UserModel newUser = UserModel.fromFirebaseUser(
          uid: uid,
          name: name,
          email: email,
          accountType: accountType,
        );

        // Generate student code if student
        if (accountType == 'student') {
          try {
            debugPrint('📚 Generating student code...');
            String studentCode = await _userService.generateStudentCode();
            newUser = newUser.copyWith(studentCode: studentCode);
            debugPrint('✅ Student code generated: $studentCode');
          } catch (e) {
            debugPrint('⚠️ Error generating student code: $e');
            debugPrint('   Continuing without student code...');
            // Continue without student code - can be added later
          }
        }

        // Save user profile to Firestore
        try {
          debugPrint('💾 Saving user profile to Firestore...');
          await _userService.createUserProfile(newUser);
          debugPrint('✅ User profile saved successfully');
          
          // Send email verification
          try {
            debugPrint('📧 Sending email verification...');
            await _authService.sendEmailVerification();
            debugPrint('✅ Email verification sent successfully');
          } catch (e) {
            debugPrint('⚠️ Error sending email verification: $e');
            // Continue even if email verification fails
          }
          
          _user = newUser;
          debugPrint('✅ User created: ${newUser.name}, Type: ${newUser.accountType}');
          // Don't save auth state yet - user needs to verify email
          await _saveAuthState(false);

          _isLoading = false;
          notifyListeners();
          return true;
        } catch (e) {
          debugPrint('❌ Error saving user profile to Firestore: $e');
          debugPrint('   Error type: ${e.runtimeType}');
          
          // Try to delete auth user if Firestore save failed
          try {
            await userCredential.user?.delete();
            debugPrint('   Auth user deleted due to Firestore error');
          } catch (deleteError) {
            debugPrint('   Error deleting auth user: $deleteError');
          }
          
          _errorMessage = 'فشل حفظ بيانات المستخدم: $e';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      debugPrint('❌ User credential is null');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ Sign up error: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      UserCredential? userCredential =
          await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential?.user != null) {
        User firebaseUser = userCredential!.user!;
        
        // Check if email is verified
        if (!firebaseUser.emailVerified) {
          _errorMessage = 'يرجى التحقق من بريدك الإلكتروني أولاً';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // Wait a bit for Firestore to be ready
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadUserProfile(firebaseUser.uid);
        // Start listening to user profile changes
        _listenToUserProfileChanges(firebaseUser.uid);
        
        // Save FCM token for push notifications
        await _saveFCMToken(firebaseUser.uid);
        
        await _saveAuthState(true);
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      UserCredential? userCredential = await _authService.signInWithGoogle();

      if (userCredential?.user != null) {
        User firebaseUser = userCredential!.user!;

        UserModel? existingUser =
            await _userService.getUserProfile(firebaseUser.uid);

        // إذا لم يكن لديه ملف أو نوع الحساب غير محدد، نوجّهه لشاشة اختيار نوع الحساب
        if (existingUser == null || existingUser.accountType.isEmpty) {
          _user = null;
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
          return true; // الدخول نجح، لكن يجب اختيار نوع الحساب قبل المتابعة
        }

        await _loadUserProfile(firebaseUser.uid);
        _listenToUserProfileChanges(firebaseUser.uid);
        await _saveFCMToken(firebaseUser.uid);
        await _saveAuthState(true);
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// إكمال التسجيل عبر Google باختيار نوع الحساب (طالب / معلم / ولي أمر).
  Future<bool> completeGoogleRegistration(String accountType) async {
    User? fb = _authService.currentUser;
    if (fb == null) {
      _errorMessage = 'لم يتم تسجيل الدخول';
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      String name = fb.displayName ?? fb.email ?? 'مستخدم';
      String email = fb.email ?? '';

      UserModel newUser = UserModel.fromFirebaseUser(
        uid: fb.uid,
        name: name,
        email: email,
        accountType: accountType,
      );

      if (accountType == 'student') {
        try {
          String studentCode = await _userService.generateStudentCode();
          newUser = newUser.copyWith(studentCode: studentCode);
        } catch (e) {
          debugPrint('⚠️ Error generating student code: $e');
        }
      }

      await _userService.createUserProfile(newUser);
      await _loadUserProfile(fb.uid);
      _listenToUserProfileChanges(fb.uid);
      await _saveFCMToken(fb.uid);
      await _saveAuthState(true);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ completeGoogleRegistration error: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Cancel stream subscription
      _userProfileSubscription?.cancel();
      _userProfileSubscription = null;

      // Remove FCM token
      if (_user != null) {
        await _removeFCMToken(_user!.uid);
      }

      await _authService.signOut();
      _user = null;
      await _saveAuthState(false);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _authService.sendPasswordResetEmail(email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Verify password reset code
  Future<bool> verifyPasswordResetCode(String code) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _authService.verifyPasswordResetCode(code);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Confirm password reset
  Future<bool> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _authService.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Send email verification
  Future<bool> sendEmailVerification() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _authService.sendEmailVerification();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Check if email is verified
  bool isEmailVerified() {
    return _authService.isEmailVerified();
  }

  // Reload user to check email verification status
  Future<bool> reloadUser() async {
    try {
      await _authService.reloadUser();
      
      // Reload user profile if email is verified
      User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        await _loadUserProfile(currentUser.uid);
      }
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Refresh user profile from Firestore (useful after XP/level updates)
  Future<void> refreshUser() async {
    if (_user != null) {
      await _loadUserProfile(_user!.uid);
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      if (_user == null) {
        _errorMessage = 'المستخدم غير موجود';
        return false;
      }

      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _userService.updateUserProfile(_user!.uid, data);
      
      // Reload user profile
      await _loadUserProfile(_user!.uid);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Reset password (for backward compatibility)
  Future<bool> resetPassword(String email) async {
    return await sendPasswordResetEmail(email);
  }

  // Save auth state locally
  Future<void> _saveAuthState(bool isLoggedIn) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Save FCM token for push notifications
  Future<void> _saveFCMToken(String userId) async {
    final service = _pushNotificationService;
    if (service != null && Platform.isAndroid) {
      try {
        await service.saveTokenForUser(userId);
        debugPrint('✅ FCM token saved for user: $userId');
      } catch (e) {
        debugPrint('❌ Error saving FCM token: $e');
      }
    }
  }

  // Remove FCM token on logout
  Future<void> _removeFCMToken(String userId) async {
    final service = _pushNotificationService;
    if (service != null && Platform.isAndroid) {
      try {
        await service.removeTokenForUser(userId);
        debugPrint('✅ FCM token removed for user: $userId');
      } catch (e) {
        debugPrint('❌ Error removing FCM token: $e');
      }
    }
  }
}
