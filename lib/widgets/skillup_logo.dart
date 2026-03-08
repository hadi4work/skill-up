import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SkillUpLogo extends StatelessWidget {
  final double? logoSize;
  final double? fontSize;
  final String? imagePath;

  const SkillUpLogo({
    super.key,
    this.logoSize = 80,
    this.fontSize = 24,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo image from assets
        SizedBox(
          width: logoSize,
          height: logoSize,
          child: Image.asset(
            imagePath ?? 'assets/images/skillup_logo.jpg',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback إذا لم توجد الصورة
              return Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.purple[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 40,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Brand name
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'SkillUp',
                style: GoogleFonts.cairo(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[600],
                ),
              ),
              TextSpan(
                text: 'AI',
                style: GoogleFonts.cairo(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
