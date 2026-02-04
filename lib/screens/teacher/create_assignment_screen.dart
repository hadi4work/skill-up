import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/class_service.dart';
import '../../services/storage_service.dart';
import '../../models/assignment_model.dart';
import '../../models/class_model.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';
import 'create_class_screen.dart';

class CreateAssignmentScreen extends StatefulWidget {
  const CreateAssignmentScreen({super.key});

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _notesController = TextEditingController();
  final AssignmentService _assignmentService = AssignmentService();
  final ClassService _classService = ClassService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  File? _assignmentImage;
  DateTime? _selectedDeadline;
  final List<String> _selectedClassIds = [];
  List<ClassModel> _teacherClasses = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeacherClasses();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadTeacherClasses() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final teacherId = authProvider.user?.uid;

    if (teacherId == null) {
      debugPrint('❌ Teacher ID is null');
      return;
    }

    debugPrint('📚 Loading classes for teacher: $teacherId');

    try {
      final classes = await _classService.getTeacherClasses(teacherId);
      debugPrint('📚 Loaded ${classes.length} classes');
      
      if (!mounted) return;
      
      setState(() {
        _teacherClasses = classes;
      });
      
      if (classes.isEmpty) {
        debugPrint('⚠️ No classes found for teacher');
      }
    } catch (e) {
      debugPrint('❌ Error loading classes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء جلب الصفوف: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _assignmentImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء اختيار الصورة: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDeadline() async {
    if (!mounted) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (!mounted) return;
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (!mounted) return;
      if (time != null) {
        setState(() {
          _selectedDeadline = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createAssignment() async {
    if (_formKey.currentState!.validate()) {
      if (_assignmentImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى التقاط صورة الواجب', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedDeadline == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى تحديد الموعد النهائي', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedClassIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى اختيار صف واحد على الأقل', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final teacherId = authProvider.user?.uid;

      if (teacherId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      try {
        // Create assignment first to get ID
        AssignmentModel newAssignment = AssignmentModel(
          id: '',
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          assignmentImageUrl: '',
          teacherId: teacherId,
          classIds: _selectedClassIds,
          deadline: _selectedDeadline!,
          createdAt: DateTime.now(),
        );

        String assignmentId = await _assignmentService.createAssignment(newAssignment);

        // Upload image
        String imageUrl = await _storageService.uploadAssignmentImage(
          _assignmentImage!,
          assignmentId,
        );

        // Update assignment with image URL
        await _assignmentService.updateAssignment(assignmentId, {
          'assignmentImageUrl': imageUrl,
        });

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إنشاء الواجب بنجاح', style: GoogleFonts.cairo()),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'إنشاء واجب جديد',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                CustomTextField(
                  label: 'عنوان الواجب',
                  placeholder: 'مثال: واجب الرياضيات - الفصل 3',
                  prefixIcon: Icons.title,
                  controller: _titleController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال عنوان الواجب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Subject
                CustomTextField(
                  label: 'المادة',
                  placeholder: 'مثال: الرياضيات، العلوم',
                  prefixIcon: Icons.book,
                  controller: _subjectController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال اسم المادة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Notes
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    hintText: 'أضف أي ملاحظات إضافية',
                    prefixIcon: const Icon(Icons.note),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  style: GoogleFonts.cairo(),
                ),
                const SizedBox(height: 24),
                // Image Picker
                Text(
                  'صورة الواجب',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _assignmentImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _assignmentImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.camera_alt,
                                size: 48,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'اضغط للتقاط صورة الواجب',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                // Deadline
                Text(
                  'الموعد النهائي',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _selectDeadline,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF2563EB)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedDeadline != null
                                ? '${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year} ${_selectedDeadline!.hour}:${_selectedDeadline!.minute.toString().padLeft(2, '0')}'
                                : 'اختر الموعد النهائي',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color: _selectedDeadline != null
                                  ? const Color(0xFF111827)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Select Classes
                Text(
                  'اختر الصفوف',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                if (_teacherClasses.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'لا توجد صفوف. يرجى إنشاء صف أولاً',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.orange[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateClassScreen(),
                              ),
                            ).then((_) {
                              _loadTeacherClasses();
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: Text('إنشاء صف جديد', style: GoogleFonts.cairo()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._teacherClasses.map((classModel) => CheckboxListTile(
                        title: Text(
                          '${classModel.name} - ${classModel.section}',
                          style: GoogleFonts.cairo(),
                        ),
                        subtitle: Text(
                          '${classModel.studentCodes.length} طالب',
                          style: GoogleFonts.cairo(fontSize: 12),
                        ),
                        value: _selectedClassIds.contains(classModel.id),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedClassIds.add(classModel.id);
                            } else {
                              _selectedClassIds.remove(classModel.id);
                            }
                          });
                        },
                      )),
                const SizedBox(height: 32),
                // Create Button
                GradientButton(
                  text: 'إنشاء الواجب',
                  onPressed: _createAssignment,
                  icon: Icons.check,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
