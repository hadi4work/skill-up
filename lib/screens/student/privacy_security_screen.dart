import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../forgot_password_screen.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'الخصوصية والأمان',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Security Options
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSecurityItem(
                    icon: Icons.lock_outline,
                    title: 'تغيير كلمة المرور',
                    subtitle: 'قم بتحديث كلمة المرور لحماية حسابك',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildSecurityItem(
                    icon: Icons.verified_user,
                    title: 'التحقق من الإيميل',
                    subtitle: 'تأكد من التحقق من بريدك الإلكتروني',
                    onTap: () {
                      // TODO: Navigate to email verification
                    },
                  ),
                  const Divider(height: 1),
                  _buildSecurityItem(
                    icon: Icons.security,
                    title: 'الأمان',
                    subtitle: 'إدارة إعدادات الأمان لحسابك',
                    onTap: () {
                      // TODO: Navigate to security settings
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Privacy Options
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'الخصوصية',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                  _buildPrivacyItem(
                    title: 'مشاركة البيانات',
                    subtitle: 'إدارة كيفية مشاركة بياناتك',
                    value: true,
                    onChanged: (value) {
                      // TODO: Update privacy setting
                    },
                  ),
                  const Divider(height: 1),
                  _buildPrivacyItem(
                    title: 'الملف الشخصي العام',
                    subtitle: 'إظهار ملفك الشخصي للآخرين',
                    value: false,
                    onChanged: (value) {
                      // TODO: Update privacy setting
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
      ),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF111827),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.cairo(
          fontSize: 12,
          color: const Color(0xFF6B7280),
        ),
      ),
      trailing: const Icon(Icons.arrow_back_ios, size: 16, color: Color(0xFF6B7280)),
      onTap: onTap,
    );
  }

  Widget _buildPrivacyItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF111827),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.cairo(
          fontSize: 12,
          color: const Color(0xFF6B7280),
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
