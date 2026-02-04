import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AccountType {
  parent,
  teacher,
  student,
}

class AccountTypeCard extends StatelessWidget {
  final AccountType type;
  final bool isSelected;
  final VoidCallback onTap;
  final String imagePath;

  const AccountTypeCard({
    super.key,
    required this.type,
    required this.isSelected,
    required this.onTap,
    required this.imagePath,
  });

  String get _label {
    switch (type) {
      case AccountType.parent:
        return 'ولي أمر';
      case AccountType.teacher:
        return 'معلم';
      case AccountType.student:
        return 'طالب';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue[400]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[100],
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _label,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
