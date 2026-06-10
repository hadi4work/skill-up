import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/class_service.dart';
import '../../services/user_service.dart';
import '../../models/class_model.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';
import 'qr_scanner_screen.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sectionController = TextEditingController();
  final _studentCodeController = TextEditingController();
  final ClassService _classService = ClassService();
  final UserService _userService = UserService();
  bool _isLoading = false;
  final List<String> _studentCodes = [];

  // For existing classes
  List<ClassModel> _classes = [];
  bool _isLoadingClasses = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadClasses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sectionController.dispose();
    _studentCodeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _isLoadingClasses = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final teacherId = authProvider.user?.uid;

    if (teacherId == null) {
      setState(() {
        _isLoadingClasses = false;
      });
      return;
    }

    try {
      final classes = await _classService.getTeacherClasses(teacherId);
      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoadingClasses = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading classes: $e');
      if (mounted) {
        setState(() {
          _isLoadingClasses = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteClass(String classId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo()),
        content: Text(
          'هل أنت متأكد من حذف هذا الصف؟ لا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('حذف', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _classService.deleteClass(classId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حذف الصف بنجاح', style: GoogleFonts.cairo()),
              backgroundColor: Colors.green,
            ),
          );
          _loadClasses();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ: $e', style: GoogleFonts.cairo()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _addStudent() async {
    String code = _studentCodeController.text.trim();
    if (code.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى إدخال كود الطالب', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if student exists
    try {
      final student = await _userService.getUserByStudentCode(code);
      if (!mounted) return;

      if (student == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('كود الطالب غير موجود', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_studentCodes.contains(code)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'الطالب موجود بالفعل في القائمة',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _studentCodes.add(code);
        _studentCodeController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeStudent(String code) {
    setState(() {
      _studentCodes.remove(code);
    });
  }

  Future<void> _createClass() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final teacherId = authProvider.user?.uid;

      if (teacherId == null) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('المعلم غير موجود', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        ClassModel newClass = ClassModel(
          id: '',
          name: _nameController.text.trim(),
          section: _sectionController.text.trim(),
          teacherId: teacherId,
          studentCodes: _studentCodes,
          createdAt: DateTime.now(),
        );

        String classId = await _classService.createClass(newClass);

        // Add class to students' profiles
        for (String studentCode in _studentCodes) {
          try {
            final student = await _userService.getUserByStudentCode(
              studentCode,
            );
            if (student != null) {
              await _userService.addClassToStudent(student.uid, classId);
            }
          } catch (e) {
            debugPrint('Error adding class to student $studentCode: $e');
          }
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _nameController.clear();
            _sectionController.clear();
            _studentCodes.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إنشاء الصف بنجاح', style: GoogleFonts.cairo()),
              backgroundColor: Colors.green,
            ),
          );
          _loadClasses();
          _tabController.animateTo(1); // Switch to classes list tab
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ: $e', style: GoogleFonts.cairo()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          'إدارة الصفوف',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2563EB),
          tabs: [
            Tab(
              child: Text(
                'إنشاء صف جديد',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Tab(
              child: Text(
                'الصفوف المنشأة (${_classes.length})',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Create New Class Tab
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Class Name
                    CustomTextField(
                      label: 'اسم الصف',
                      placeholder: 'مثال: الصف الخامس',
                      prefixIcon: Icons.class_,
                      controller: _nameController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال اسم الصف';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Section
                    CustomTextField(
                      label: 'الشعبة',
                      placeholder: 'مثال: أ، ب، ج',
                      prefixIcon: Icons.group,
                      controller: _sectionController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال الشعبة';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    // Add Students Section
                    Text(
                      'إضافة طلاب',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'كود الطالب',
                            placeholder: 'أدخل كود الطالب',
                            prefixIcon: Icons.qr_code,
                            controller: _studentCodeController,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QRScannerScreen(
                                  onCodeScanned: (code) {
                                    _studentCodeController.text = code;
                                    _addStudent();
                                  },
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.qr_code_scanner, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addStudent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Students List
                    if (_studentCodes.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'قائمة الطلاب (${_studentCodes.length})',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._studentCodes.map(
                              (code) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      color: Color(0xFF2563EB),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        code,
                                        style: GoogleFonts.cairo(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _removeStudent(code),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    // Create Button
                    GradientButton(
                      text: 'إنشاء الصف',
                      onPressed: _createClass,
                      icon: Icons.check,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Existing Classes Tab
          _buildClassesListTab(),
        ],
      ),
    );
  }

  Widget _buildClassesListTab() {
    if (_isLoadingClasses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد صفوف منشأة',
              style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClasses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _classes.length,
        itemBuilder: (context, index) {
          return _buildClassCard(_classes[index]);
        },
      ),
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.class_, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classModel.name,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الشعبة: ${classModel.section}',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditClassDialog(classModel);
                  } else if (value == 'delete') {
                    _deleteClass(classModel.id);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Text('تعديل', style: GoogleFonts.cairo()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'حذف',
                          style: GoogleFonts.cairo(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.people, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${classModel.studentCodes.length} طالب',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showEditClassDialog(classModel),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2563EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'تعديل الصف',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addStudentCodeToEditDialog(
    String code,
    List<String> studentCodes,
    void Function(void Function()) setDialogState,
  ) async {
    try {
      final student = await _userService.getUserByStudentCode(code);
      if (student == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'كود الطالب غير موجود',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      if (studentCodes.contains(code)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'الطالب موجود بالفعل',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      setDialogState(() {
        studentCodes.add(code);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditClassDialog(ClassModel classModel) {
    final nameController = TextEditingController(text: classModel.name);
    final sectionController = TextEditingController(text: classModel.section);
    final studentCodeController = TextEditingController();
    List<String> studentCodes = List.from(classModel.studentCodes);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('تعديل الصف', style: GoogleFonts.cairo()),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم الصف',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: GoogleFonts.cairo(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sectionController,
                    decoration: InputDecoration(
                      labelText: 'الشعبة',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: GoogleFonts.cairo(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'الطلاب (${studentCodes.length})',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: studentCodeController,
                          decoration: InputDecoration(
                            labelText: 'كود الطالب',
                            labelStyle: GoogleFonts.cairo(),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: GoogleFonts.cairo(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          // الماسح يستدعي onCodeScanned ثم Navigator.pop بنفسه؛ لا تُغلق مساراً ثانياً هنا.
                          final code = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QRScannerScreen(
                                onCodeScanned: (_) {},
                              ),
                            ),
                          );
                          if (code == null || code.isEmpty) return;
                          await _addStudentCodeToEditDialog(
                            code,
                            studentCodes,
                            setDialogState,
                          );
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: 'قراءة باركود الطالب',
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          String code = studentCodeController.text.trim();
                          if (code.isEmpty) return;
                          await _addStudentCodeToEditDialog(
                            code,
                            studentCodes,
                            setDialogState,
                          );
                          studentCodeController.clear();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (studentCodes.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: studentCodes.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(
                              studentCodes[index],
                              style: GoogleFonts.cairo(),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setDialogState(() {
                                  studentCodes.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty ||
                          sectionController.text.trim().isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'يرجى إدخال جميع البيانات',
                                style: GoogleFonts.cairo(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                      });

                      try {
                        // Update class name and section
                        await _classService.updateClass(classModel.id, {
                          'name': nameController.text.trim(),
                          'section': sectionController.text.trim(),
                          'studentCodes': studentCodes,
                        });

                        // Update students' class lists
                        final authProvider = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        final teacherId = authProvider.user?.uid;

                        if (teacherId != null) {
                          // Remove class from old students
                          for (String oldCode in classModel.studentCodes) {
                            if (!studentCodes.contains(oldCode)) {
                              try {
                                final student = await _userService
                                    .getUserByStudentCode(oldCode);
                                if (student != null) {
                                  // Remove class from student
                                  List<String> studentClasses = List.from(
                                    student.classIds ?? [],
                                  );
                                  studentClasses.remove(classModel.id);
                                  await _userService.updateUserProfile(
                                    student.uid,
                                    {'classIds': studentClasses},
                                  );
                                }
                              } catch (e) {
                                debugPrint(
                                  'Error removing class from student: $e',
                                );
                              }
                            }
                          }

                          // Add class to new students
                          for (String newCode in studentCodes) {
                            if (!classModel.studentCodes.contains(newCode)) {
                              try {
                                final student = await _userService
                                    .getUserByStudentCode(newCode);
                                if (student != null) {
                                  await _userService.addClassToStudent(
                                    student.uid,
                                    classModel.id,
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error adding class to student: $e');
                              }
                            }
                          }
                        }

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تم تحديث الصف بنجاح',
                                style: GoogleFonts.cairo(),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadClasses();
                        }
                      } catch (e) {
                        if (mounted) {
                          setDialogState(() {
                            isLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'حدث خطأ: $e',
                                style: GoogleFonts.cairo(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('حفظ', style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
