import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../widgets/skillup_logo.dart';
import '../widgets/gradient_button.dart';
import '../providers/auth_provider.dart';
import 'reset_password_screen.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String email;

  const VerifyCodeScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getCode() {
    // Get code from first controller (full action code)
    return _codeControllers[0].text.trim();
  }

  void _handleVerifyCode() async {
    String code = _getCode();
    
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى إدخال كود التحقق',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Note: Firebase sends a link with action code, not a 6-digit OTP
    // The action code is in the email link (oobCode parameter)
    // For testing, you can use the action code from the email link
    // In production, you would extract it from deep linking
    bool success = await authProvider.verifyPasswordResetCode(code);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      // Navigate to reset password screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(
            email: widget.email,
            code: code,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'الكود غير صحيح أو منتهي الصلاحية',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Logo
              const SkillUpLogo(logoSize: 80, fontSize: 24),
              const SizedBox(height: 32),
              // Title
              Text(
                'أدخل كود التحقق',
                style: GoogleFonts.cairo(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                'تم إرسال كود التحقق إلى\n${widget.email}',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 40),
              // Code input fields - Note: Firebase action code is longer than 6 digits
              // This UI accepts the action code from the email link
              TextField(
                controller: _codeControllers[0],
                focusNode: _focusNodes[0],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.text,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'أدخل كود التحقق من الرابط',
                  hintText: 'انسخ الكود من رابط الإيميل',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (value) {
                  // Allow full code input
                },
              ),
              const SizedBox(height: 16),
              // Alternative: 6-digit OTP style (for future OTP implementation)
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              //   children: List.generate(6, (index) {
              //     return SizedBox(
              //       width: 45,
              //       height: 55,
              //       child: TextField(
              //         controller: _codeControllers[index],
              //         focusNode: _focusNodes[index],
              //         textAlign: TextAlign.center,
              //         keyboardType: TextInputType.number,
              //         maxLength: 1,
              //         style: GoogleFonts.cairo(
              //           fontSize: 24,
              //           fontWeight: FontWeight.bold,
              //         ),
              //         decoration: InputDecoration(
              //           counterText: '',
              //           border: OutlineInputBorder(
              //             borderRadius: BorderRadius.circular(12),
              //             borderSide: BorderSide(color: Colors.grey[300]!),
              //           ),
              //           enabledBorder: OutlineInputBorder(
              //             borderRadius: BorderRadius.circular(12),
              //             borderSide: BorderSide(color: Colors.grey[300]!),
              //           ),
              //           focusedBorder: OutlineInputBorder(
              //             borderRadius: BorderRadius.circular(12),
              //             borderSide: const BorderSide(
              //               color: Color(0xFF2563EB),
              //               width: 2,
              //             ),
              //           ),
              //           filled: true,
              //           fillColor: Colors.grey[50],
              //         ),
              //         onChanged: (value) => _onCodeChanged(index, value),
              //       ),
              //     );
              //   }),
              // ),
              const SizedBox(height: 24),
              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'كيفية الحصول على الكود:',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. افتح بريدك الإلكتروني\n2. افتح رابط إعادة التعيين\n3. انسخ الكود من الرابط (oobCode=...)',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.blue[900],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Verify button
              GradientButton(
                text: 'التحقق من الكود',
                onPressed: _handleVerifyCode,
                icon: Icons.check_circle,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),
              // Resend code
              TextButton(
                onPressed: () {
                  // TODO: Resend code
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم إعادة إرسال الكود',
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text(
                  'إعادة إرسال الكود',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[600],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
