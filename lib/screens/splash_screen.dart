import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF87CEEB),
              Color(0xFFB0E0E6),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/skillup_logo.jpg',
                  width: 180,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.school,
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'SkillUp AI',
                style: GoogleFonts.cairo(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A5F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'التعلّم الذكي يبدأ هنا',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: const Color(0xFF1E3A5F),
                ),
              ),
              const Spacer(flex: 2),
              const Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
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
