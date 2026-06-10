import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_service.dart';

enum _HomeworkHelpMode { hints, full }

/// شاشة مساعد الذكاء الاصطناعي — تلميحات واجب، أو محادثة عامة، أو واجهة بعد استخراج أسئلة من صورة.
class AIAssistantScreen extends StatefulWidget {
  final String? subject;
  /// وضع قديم: سؤال نصي قصير من الواجب
  final String? question;
  final String? studentAnswer;
  /// نص الأسئلة المستخرج من صورة الواجب (يتفعّل تدفق «تلميحات / حل»)
  final String? extractedHomeworkQuestions;

  const AIAssistantScreen({
    super.key,
    this.subject,
    this.question,
    this.studentAnswer,
    this.extractedHomeworkQuestions,
  });

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _isStreamingReply = false;
  String? _error;
  final List<_ChatMessage> _messages = [];

  String? _homeworkBlob;
  _HomeworkHelpMode? _homeworkMode;

  static const _systemHomeworkHints = '''
أنت معلم مساعد للواجبات المدرسية.
الطالب اختار التلميحات فقط: قدّم توجيهاً وتلميحات تدريجية دون إعطاء الحل النهائي كاملاً في المرة الأولى ما لم يطلب ذلك صراحة في رسالة لاحقة.
اكتب بالعربية بوضوح.''';

  static const _systemHomeworkFull = '''
أنت معلم مساعد للواجبات المدرسية.
الطالب اختار شرح الحل الكامل: قدّم حلولاً واضحة ومفصّلة للأسئلة المعروضة.
اكتب بالعربية بوضوح.''';

  bool get _isExtractedHomeworkFlow =>
      (widget.extractedHomeworkQuestions ?? '').trim().isNotEmpty;

  bool get _isLegacyHintMode =>
      !_isExtractedHomeworkFlow &&
      widget.question != null &&
      widget.question!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isExtractedHomeworkFlow) {
      _homeworkBlob = widget.extractedHomeworkQuestions!.trim();
      _messages.add(
        _ChatMessage(
          text:
              'راجعتُ نص الأسئلة الذي أرسلته من صورة الواجب.\n\n'
              'هل تريد **تلميحات** توجّهك خطوة بخطوة دون الحل الكامل، أم **حلاً كاملاً** لهذه الأسئلة؟\n\n'
              'اكتب: **تلميحات** أو **حل**',
          isUser: false,
        ),
      );
    } else if (_isLegacyHintMode) {
      _messages.add(
        _ChatMessage(
          text:
              'مرحباً! سأعطيك تلميحات قصيرة دون كشف الإجابة الكاملة.',
          isUser: false,
        ),
      );
      _messages.add(_ChatMessage(text: 'السؤال: ${widget.question}', isUser: true));
      if (widget.studentAnswer != null && widget.studentAnswer!.trim().isNotEmpty) {
        _messages.add(
          _ChatMessage(text: 'محاولتي: ${widget.studentAnswer}', isUser: true),
        );
      }
    } else {
      _messages.add(
        _ChatMessage(
          text: 'مرحباً! كيف أساعدك اليوم؟',
          isUser: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _HomeworkHelpMode? _parseHomeworkChoice(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.contains('تلميح')) return _HomeworkHelpMode.hints;
    final lower = t.toLowerCase();
    if (lower.contains('hint')) return _HomeworkHelpMode.hints;
    if (t.contains('حل') && !t.contains('تلميح')) {
      return _HomeworkHelpMode.full;
    }
    return null;
  }

  List<Map<String, String>> _historyMaps() {
    return _messages
        .where((m) => m.text.trim().isNotEmpty)
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();
  }

  Future<void> _sendPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    FocusScope.of(context).unfocus();
    _promptController.clear();
    setState(() {
      _loading = true;
      _error = null;
      _messages.add(_ChatMessage(text: prompt, isUser: true));
    });
    _scrollToBottom(animated: true);

    try {
      if (_isExtractedHomeworkFlow && _homeworkBlob != null) {
        if (_homeworkMode == null) {
          final choice = _parseHomeworkChoice(prompt);
          if (choice == null) {
            if (mounted) {
              await _streamAssistantReply(
                'لم أتأكد من اختيارك. اكتب **تلميحات** إذا أردت توجيهاً فقط، أو **حل** إذا أردت شرح الحل كاملاً.',
              );
              setState(() => _loading = false);
            }
            return;
          }
          _homeworkMode = choice;
          final system =
              choice == _HomeworkHelpMode.hints
                  ? _systemHomeworkHints
                  : _systemHomeworkFull;
          final firstPrompt =
              'المادة: ${widget.subject ?? 'عام'}\n\n'
              'الأسئلة (من صورة الواجب):\n'
              '---\n'
              '$_homeworkBlob\n'
              '---\n\n'
              'اختيار الطالب: ${choice == _HomeworkHelpMode.hints ? 'تلميحات فقط' : 'حل كامل'}\n\n'
              'ابدأ الآن بمساعدة الطالب وفق هذا الاختيار.';
          final text = await _aiService.chat(
            prompt: firstPrompt,
            systemPrompt: system,
            history: const [],
          );
          if (mounted) await _streamAssistantReply(text);
          return;
        }

        final system =
            _homeworkMode == _HomeworkHelpMode.hints
                ? _systemHomeworkHints
                : _systemHomeworkFull;
        final contextual =
            'المادة: ${widget.subject ?? 'عام'}\n'
            'الأسئلة المرجعية (واجب):\n---\n$_homeworkBlob\n---\n\n'
            'رسالة الطالب:\n$prompt';
        final text = await _aiService.chat(
          prompt: contextual,
          systemPrompt: system,
          history: _historyMaps(),
        );
        if (mounted) await _streamAssistantReply(text);
        return;
      }

      if (_isLegacyHintMode) {
        final history = _historyMaps();
        final text = await _aiService.getHint(
          subject: widget.subject ?? 'عام',
          question: widget.question ?? prompt,
          studentAnswer: prompt,
          history: history,
        );
        if (mounted) await _streamAssistantReply(text);
        return;
      }

      final text = await _aiService.chat(
        prompt: prompt,
        history: _historyMaps(),
      );
      if (mounted) await _streamAssistantReply(text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent + 60;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _streamAssistantReply(String fullText) async {
    setState(() {
      _loading = false;
      _isStreamingReply = true;
      _messages.add(_ChatMessage(text: '', isUser: false));
    });
    final chunks = fullText.runes.toList();
    const step = 8;
    for (int i = 0; i < chunks.length; i += step) {
      if (!mounted) return;
      final end = (i + step) > chunks.length ? chunks.length : (i + step);
      final current = String.fromCharCodes(chunks.take(end));
      setState(() {
        final last = _messages.last;
        _messages[_messages.length - 1] = _ChatMessage(
          text: current,
          isUser: last.isUser,
        );
      });
      await Future.delayed(const Duration(milliseconds: 1));
    }

    if (!mounted) return;
    setState(() {
      _isStreamingReply = false;
    });
    _scrollToBottom(animated: true);
  }

  String get _appBarTitle {
    if (_isExtractedHomeworkFlow) return 'مساعد الواجب';
    if (_isLegacyHintMode) return 'تلميح من الذكاء الاصطناعي';
    return 'مساعد الذكاء الاصطناعي';
  }

  String get _inputHint {
    if (_isExtractedHomeworkFlow && _homeworkMode == null) {
      return 'اكتب: تلميحات — أو — حل';
    }
    if (_isLegacyHintMode) {
      return 'اكتب محاولتك لنقدّم تلميحاً...';
    }
    return 'اكتب رسالتك...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _appBarTitle,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              itemCount: _messages.length + (_loading ? 1 : 0) + (_error != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (_error != null && index == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: GoogleFonts.cairo(color: Colors.red.shade900),
                    ),
                  );
                }
                final errorShift = _error != null ? 1 : 0;
                final adjusted = index - errorShift;
                if (_loading && adjusted == _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text('يفكر...', style: GoogleFonts.cairo(fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }
                final msg = _messages[adjusted];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: msg.isUser ? const Color(0xFF2563EB) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: msg.isUser
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: SelectableText(
                      msg.text,
                      style: GoogleFonts.cairo(
                        color: msg.isUser ? Colors.white : const Color(0xFF111827),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _loading ? null : _sendPrompt(),
                      decoration: InputDecoration(
                        hintText: _inputHint,
                        hintStyle: GoogleFonts.cairo(fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: GoogleFonts.cairo(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: (_loading || _isStreamingReply) ? null : _sendPrompt,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                      child: (_loading || _isStreamingReply)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
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

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({
    required this.text,
    required this.isUser,
  });
}
