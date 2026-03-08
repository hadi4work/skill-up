import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../widgets/skillup_logo.dart';
import '../widgets/account_type_card.dart';
import '../widgets/gradient_button.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

/// تظهر بعد تسجيل الدخول بـ Google لأول مرة؛ المستخدم لا يستطيع المتابعة دون اختيار نوع الحساب.
class ChooseAccountTypeScreen extends StatefulWidget {
  const ChooseAccountTypeScreen({super.key});

  @override
  State<ChooseAccountTypeScreen> createState() => _ChooseAccountTypeScreenState();
}

class _ChooseAccountTypeScreenState extends State<ChooseAccountTypeScreen> {
  AccountType? _selectedAccountType;
  bool _isLoading = false;

  String get _accountTypeString {
    if (_selectedAccountType == AccountType.student) return 'student';
    if (_selectedAccountType == AccountType.teacher) return 'teacher';
    return 'parent';
  }

  Future<void> _submit() async {
    if (_selectedAccountType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى اختيار نوع الحساب', style: GoogleFonts.cairo()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = await authProvider.completeGoogleRegistration(_accountTypeString);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage!,
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
    // عند النجاح، AuthWrapper سيعيد البناء ويعرض الصفحة الرئيسية المناسبة
  }

  Future<void> _signOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final fbUser = authProvider.firebaseUser;
    final displayName = fbUser?.displayName ?? fbUser?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const SkillUpLogo(logoSize: 72, fontSize: 22),
              const SizedBox(height: 24),
              Text(
                'اختر نوع الحساب',
                style: GoogleFonts.cairo(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'لا يمكنك الدخول دون اختيار نوع الحساب',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              if (displayName.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  AccountTypeCard(
                    type: AccountType.parent,
                    isSelected: _selectedAccountType == AccountType.parent,
                    onTap: () => setState(() => _selectedAccountType = AccountType.parent),
                    imagePath: 'assets/images/parents.png',
                  ),
                  AccountTypeCard(
                    type: AccountType.teacher,
                    isSelected: _selectedAccountType == AccountType.teacher,
                    onTap: () => setState(() => _selectedAccountType = AccountType.teacher),
                    imagePath: 'assets/images/teacher.png',
                  ),
                  AccountTypeCard(
                    type: AccountType.student,
                    isSelected: _selectedAccountType == AccountType.student,
                    onTap: () => setState(() => _selectedAccountType = AccountType.student),
                    imagePath: 'assets/images/student.png',
                  ),
                ],
              ),
              const SizedBox(height: 40),
              GradientButton(
                text: 'متابعة',
                onPressed: _submit,
                icon: Icons.arrow_back,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : _signOut,
                child: Text(
                  'تسجيل الخروج',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
