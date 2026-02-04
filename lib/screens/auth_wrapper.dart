import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'onboarding_page.dart';
import 'login_screen.dart';
import 'student/student_home_screen.dart';
import 'teacher/teacher_home_screen.dart';
import 'parent/parent_home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading while checking auth state (only on initial load)
        if (authProvider.isLoading && authProvider.user == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'جاري التحميل...',
                    style: GoogleFonts.cairo(),
                  ),
                ],
              ),
            ),
          );
        }

        // If user is authenticated, show appropriate home screen
        if (authProvider.isAuthenticated && authProvider.user != null) {
          String accountType = authProvider.user!.accountType;
          debugPrint('Navigating to home screen for account type: $accountType');
          
          switch (accountType) {
            case 'student':
              return const StudentHomeScreen();
            case 'teacher':
              return const TeacherHomeScreen();
            case 'parent':
              return const ParentHomeScreen();
            default:
              debugPrint('Unknown account type: $accountType, showing login');
              return const LoginScreen();
          }
        }

        // Show onboarding for new users
        return const OnboardingPage();
      },
    );
  }
}
