import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../widgets/skillup_logo.dart';
import '../widgets/account_type_card.dart';
import '../widgets/gradient_button.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

/// تظهر بعد أول تسجيل دخول بدون ملف (يدوي أو Google) لإكمال الاسم ونوع الحساب.
class ChooseAccountTypeScreen extends StatefulWidget {
  const ChooseAccountTypeScreen({super.key});

  @override
  State<ChooseAccountTypeScreen> createState() => _ChooseAccountTypeScreenState();
}

class _ChooseAccountTypeScreenState extends State<ChooseAccountTypeScreen> {
  AccountType? _selectedAccountType;
  /// male | female
  String? _selectedGender;
  bool _isLoading = false;
  final TextEditingController _nameController = TextEditingController();

  String get _accountTypeString {
    if (_selectedAccountType == AccountType.student) return 'student';
    if (_selectedAccountType == AccountType.teacher) return 'teacher';
    return 'parent';
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى إدخال الاسم', style: GoogleFonts.cairo()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedAccountType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى اختيار نوع الحساب', style: GoogleFonts.cairo()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى تحديد الجنس', style: GoogleFonts.cairo()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = await authProvider.completeAccountSetup(
      _accountTypeString,
      name: _nameController.text.trim(),
      gender: _selectedGender,
    );

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
    if (_nameController.text.isEmpty && (fbUser?.displayName?.isNotEmpty ?? false)) {
      _nameController.text = fbUser!.displayName!;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const SkillUpLogo(logoSize: 72, fontSize: 22, showBrandName: false),
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
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Text(
                  'أكمل بياناتك للمتابعة',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3730A3),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (displayName.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'الحساب: $displayName',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'الاسم',
                  labelStyle: GoogleFonts.cairo(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'الجنس',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _genderChip(
                      label: 'ذكر',
                      value: 'male',
                      selected: _selectedGender == 'male',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _genderChip(
                      label: 'أنثى',
                      value: 'female',
                      selected: _selectedGender == 'female',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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

  Widget _genderChip({
    required String label,
    required String value,
    required bool selected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : () => setState(() => _selectedGender = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEEF2FF) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF6366F1) : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? const Color(0xFF3730A3) : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
