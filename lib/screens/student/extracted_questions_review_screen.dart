import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../services/ai_service.dart';
import '../ai_assistant_screen.dart';
import '../image_viewer_screen.dart';

/// بعد استخراج نص أسئلة الواجب بالذكاء الاصطناعي: تعديل، نسخ، ثم طلب المساعدة.
class ExtractedQuestionsReviewScreen extends StatefulWidget {
  final String imageUrl;
  final String subject;
  final String? assignmentTitle;

  const ExtractedQuestionsReviewScreen({
    super.key,
    required this.imageUrl,
    required this.subject,
    this.assignmentTitle,
  });

  @override
  State<ExtractedQuestionsReviewScreen> createState() =>
      _ExtractedQuestionsReviewScreenState();
}

class _ExtractedQuestionsReviewScreenState
    extends State<ExtractedQuestionsReviewScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _textController = TextEditingController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runExtraction());
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _runExtraction() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode != 200) {
        throw 'فشل تحميل الصورة: ${response.statusCode}';
      }
      final base64Image = base64Encode(response.bodyBytes);
      final text = await _aiService.extractTextFromImage(base64Image);
      if (!mounted) return;
      _textController.text = text;
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _copyAll() async {
    final t = _textController.text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا يوجد نص للنسخ', style: GoogleFonts.cairo()),
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: _textController.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم نسخ النص', style: GoogleFonts.cairo()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openAssistant() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يمكن طلب المساعدة دون نص للأسئلة. استخرج النص أو اكتبه يدوياً.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => AIAssistantScreen(
          subject: widget.subject,
          extractedHomeworkQuestions: text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'نص أسئلة الواجب',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'عرض الصورة بالحجم الكامل',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => ImageViewerScreen(
                    imageUrl: widget.imageUrl,
                    title: widget.assignmentTitle,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.fullscreen, color: Color(0xFF2563EB)),
          ),
          if (!_loading)
            IconButton(
              tooltip: 'إعادة الاستخراج',
              onPressed: _runExtraction,
              icon: const Icon(Icons.refresh, color: Color(0xFF2563EB)),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.assignmentTitle != null &&
              widget.assignmentTitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  widget.assignmentTitle!,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'راجع النص وصحّحه إن لزم، ثم اطلب المساعدة. المساعد سيسألك إن كنت تريد تلميحات أم حلاً كاملاً.',
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: const Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  color: Colors.red.shade800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _runExtraction,
                                child: Text(
                                  'إعادة المحاولة',
                                  style: GoogleFonts.cairo(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText:
                                'سيظهر هنا النص المستخرج بالذكاء الاصطناعي…',
                            hintStyle: GoogleFonts.cairo(
                              fontSize: 14,
                              color: const Color(0xFF9CA3AF),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            height: 1.5,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _copyAll,
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    label: Text(
                      'نسخ النص كاملاً',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _openAssistant,
                    icon: const Icon(Icons.smart_toy_outlined, color: Colors.white),
                    label: Text(
                      'طلب المساعدة من الذكاء الاصطناعي',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
