import '../models/assignment_model.dart';
import '../models/exam_question_model.dart';
import '../models/submission_model.dart';
import 'assignment_service.dart';
import 'exam_service.dart';

/// عنصر مراجعة مُخزَّن في [mistakeTrainingPending] ويُزال عند إتقان التدريب.
class MistakePendingItem {
  final String id;
  final Map<String, dynamic> raw;

  MistakePendingItem({required this.id, required this.raw});

  static String examKey(String examId, String questionId) => 'e_${examId}_$questionId';
  static String assignmentKey(String assignmentId) => 'a_$assignmentId';
}

/// جمع أخطاء الاختبارات/الوظائف المؤقتة والواجبات الضعيفة كخرائط جاهزة للمزامنة مع Firestore.
class MistakeTrainingService {
  final ExamService _examService = ExamService();
  final AssignmentService _assignmentService = AssignmentService();

  Future<List<Map<String, dynamic>>> discoverMistakeItems({
    required String studentId,
    required List<String> classIds,
    Set<String> excludeIds = const {},
  }) async {
    final out = <Map<String, dynamic>>[];

    final attempts = await _examService.getStudentFinishedAttempts(studentId);
    for (final attempt in attempts) {
      final exam = await _examService.getExamById(attempt.examId);
      final examSubject = exam?.subject ?? 'مادة عامة';
      final questions = await _examService.getExamQuestions(attempt.examId);
      final qMap = {for (final q in questions) q.id: q};
      final answers = await _examService.getAttemptAnswers(attempt.id);

      for (final answer in answers) {
        final ExamQuestionModel? q = qMap[answer.questionId];
        if (q == null) continue;
        final gained = answer.autoScore + answer.manualScore;
        final lowThreshold = (q.maxPoints * 0.6);
        final isLow = gained < lowThreshold;
        final isWrongChoice =
            (q.isSingleChoice || q.isTrueFalse) && (answer.isCorrect == false);
        if (!isWrongChoice && !isLow) continue;

        final id = MistakePendingItem.examKey(attempt.examId, q.id);
        final originalType = q.isEssay
            ? 'essay'
            : q.isTrueFalse
                ? 'true_false'
                : 'single_choice';

        out.add({
          'id': id,
          'source': 'exam',
          'examId': attempt.examId,
          'questionId': q.id,
          'subject': examSubject,
          'originalType': originalType,
          'questionText': q.text.trim(),
          'options': List<String>.from(q.options),
          'correctOptionIndex': q.correctOptionIndex,
          'correctIsTrue': q.correctIsTrue,
          'rubric': q.rubric,
          'maxPoints': q.maxPoints,
          'studentPickedIndex': answer.selectedOptionIndex,
          'studentEssay': answer.essayText,
        });
      }
    }

    final submissions = await _assignmentService.getSubmissionsByStudentId(studentId);
    final assignments = classIds.isEmpty
        ? <AssignmentModel>[]
        : await _assignmentService.getStudentAssignments(classIds);
    final assignmentById = {for (final a in assignments) a.id: a};

    for (final SubmissionModel s in submissions) {
      if (!s.isGraded || s.grade == null) continue;
      final assignment = assignmentById[s.assignmentId];
      if (assignment == null || assignment.totalPoints <= 0) continue;
      final percent = (s.grade! / assignment.totalPoints) * 100;
      if (percent >= 60) continue;

      final id = MistakePendingItem.assignmentKey(assignment.id);
      out.add({
        'id': id,
        'source': 'assignment',
        'assignmentId': assignment.id,
        'subject': assignment.subject,
        'originalType': 'assignment_weak',
        'questionText':
            'واجب: ${assignment.title} (${assignment.subject}) — راجع المفاهيم الأساسية لهذا الواجب.',
        'options': <String>[],
        'correctOptionIndex': null,
        'correctIsTrue': null,
        'rubric': null,
        'maxPoints': null,
        'studentPickedIndex': null,
        'studentEssay': null,
      });
    }

    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final m in out) {
      final id = m['id'] as String?;
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      if (excludeIds.contains(id)) continue;
      seen.add(id);
      deduped.add(m);
    }
    return deduped;
  }
}
