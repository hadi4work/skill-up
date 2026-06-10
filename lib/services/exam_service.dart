import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/class_model.dart';
import '../models/exam_attempt_answer_model.dart';
import '../models/exam_attempt_model.dart';
import '../models/exam_model.dart';
import '../models/exam_question_model.dart';
import '../models/user_model.dart';
import 'ai_service.dart';
import 'class_service.dart';
import 'notification_service.dart';
import 'user_service.dart';

class ExamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ClassService _classService = ClassService();
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();
  final AIService _aiService = AIService();

  final String _examsCollection = 'exams';
  final String _answersCollection = 'exam_attempt_answers';
  final String _attemptsCollection = 'exam_attempts';

  Future<String> createExam(ExamModel exam, List<ExamQuestionModel> questions) async {
    try {
      final docRef = await _firestore.collection(_examsCollection).add(
            exam
                .copyWith(
                  questionCount: questions.length,
                  isPublished: false,
                  status: 'draft',
                )
                .toMap(),
          );
      await docRef.update({'id': docRef.id});

      for (final q in questions) {
        final qRef = await docRef.collection('questions').add(q.toMap());
        await qRef.update({'id': qRef.id});
      }
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating exam: $e');
      throw 'حدث خطأ أثناء إنشاء الاختبار: $e';
    }
  }

  Future<void> updateExamMeta(String examId, Map<String, dynamic> data) async {
    await _firestore.collection(_examsCollection).doc(examId).update(data);
  }

  Future<void> replaceExamQuestions(String examId, List<ExamQuestionModel> questions) async {
    final questionsRef = _firestore.collection(_examsCollection).doc(examId).collection('questions');
    final existing = await questionsRef.get();
    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    for (final q in questions) {
      final qRef = await questionsRef.add(q.toMap());
      await qRef.update({'id': qRef.id});
    }
    await _firestore.collection(_examsCollection).doc(examId).update({'questionCount': questions.length});
  }

  Future<void> publishExam(String examId) async {
    final exam = await getExamById(examId);
    if (exam == null) throw 'الاختبار غير موجود';

    await _firestore.collection(_examsCollection).doc(examId).update({
      'isPublished': true,
      'status': 'published',
    });

    await _notificationService.createExamNotifications(exam);
  }

  Future<ExamModel?> getExamById(String examId) async {
    final doc = await _firestore.collection(_examsCollection).doc(examId).get();
    if (!doc.exists) return null;
    return ExamModel.fromMap(doc.data()!);
  }

  Future<List<ExamQuestionModel>> getExamQuestions(String examId) async {
    final snapshot = await _firestore
        .collection(_examsCollection)
        .doc(examId)
        .collection('questions')
        .orderBy('order')
        .get();
    return snapshot.docs.map((d) => ExamQuestionModel.fromMap(d.data())).toList();
  }

  Future<List<ExamModel>> getTeacherExams(String teacherId, {String assessmentType = 'exam'}) async {
    final snapshot = await _firestore
        .collection(_examsCollection)
        .where('teacherId', isEqualTo: teacherId)
        .where('assessmentType', isEqualTo: assessmentType)
        .get();
    final items = snapshot.docs.map((d) => ExamModel.fromMap(d.data())).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// اختبارات/وظائف مؤقتة منشورة مرتبطة بصفوف الطالب (للتحليلات والترتيب — ليست مقيدة بالنافذة الزمنية).
  Future<List<ExamModel>> getPublishedExamsForStudentClasses(List<String> classIds) async {
    if (classIds.isEmpty) return [];
    final byId = <String, ExamModel>{};
    for (var i = 0; i < classIds.length; i += 10) {
      final chunk = classIds.sublist(i, i + 10 > classIds.length ? classIds.length : i + 10);
      final snapshot = await _firestore
          .collection(_examsCollection)
          .where('isPublished', isEqualTo: true)
          .where('classIds', arrayContainsAny: chunk)
          .get();
      for (final doc in snapshot.docs) {
        final e = ExamModel.fromMap(doc.data());
        byId[e.id] = e;
      }
    }
    final items = byId.values.toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<List<ExamModel>> getStudentAvailableExams(List<String> classIds, {String assessmentType = 'exam'}) async {
    if (classIds.isEmpty) return [];
    final snapshot = await _firestore
        .collection(_examsCollection)
        .where('assessmentType', isEqualTo: assessmentType)
        .where('isPublished', isEqualTo: true)
        .where('classIds', arrayContainsAny: classIds)
        .get();

    final now = DateTime.now();
    final exams = snapshot.docs.map((d) => ExamModel.fromMap(d.data())).where((e) {
      return e.startAt.isBefore(now) && e.endAt.isAfter(now);
    }).toList();
    exams.sort((a, b) => a.startAt.compareTo(b.startAt));
    return exams;
  }

  Future<ExamAttemptModel> startAttempt({
    required String examId,
    required String studentId,
  }) async {
    final existing = await _firestore
        .collection(_attemptsCollection)
        .where('examId', isEqualTo: examId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return ExamAttemptModel.fromMap(existing.docs.first.data());
    }

    final newAttempt = ExamAttemptModel(
      id: '',
      examId: examId,
      studentId: studentId,
      startedAt: DateTime.now(),
      currentQuestionOrder: 0,
      isFinished: false,
      scoreAuto: 0,
      scoreManual: 0,
      scoreFinal: 0,
    );
    final docRef = await _firestore.collection(_attemptsCollection).add(newAttempt.toMap());
    await docRef.update({'id': docRef.id});
    return newAttempt.copyWith(id: docRef.id);
  }

  Future<ExamAttemptModel?> getAttempt(String examId, String studentId) async {
    final existing = await _firestore
        .collection(_attemptsCollection)
        .where('examId', isEqualTo: examId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    if (existing.docs.isEmpty) return null;
    return ExamAttemptModel.fromMap(existing.docs.first.data());
  }

  Future<void> submitAnswer({
    required ExamAttemptModel attempt,
    required ExamQuestionModel question,
    int? selectedOptionIndex,
    String? essayText,
    required bool timeExpired,
  }) async {
    int autoScore = 0;
    bool? isCorrect;
    var isAuto = question.isSingleChoice;

    if (question.isSingleChoice && selectedOptionIndex != null) {
      isCorrect = selectedOptionIndex == question.correctOptionIndex;
      autoScore = isCorrect == true ? question.maxPoints : 0;
    } else if (question.isTrueFalse && selectedOptionIndex != null) {
      final correctT = question.correctIsTrue ?? true;
      final studentSaysTrue = selectedOptionIndex == 0;
      isCorrect = studentSaysTrue == correctT;
      final tfPts = question.trueFalsePoints > 0 ? question.trueFalsePoints : question.maxPoints;
      autoScore = isCorrect == true ? tfPts : 0;
      final needsEssayGrade =
          question.justifyIfStatementFalse && correctT == false;
      if (needsEssayGrade) {
        isAuto = false;
      }
    }

    final answer = ExamAttemptAnswerModel(
      id: '',
      attemptId: attempt.id,
      examId: attempt.examId,
      studentId: attempt.studentId,
      questionId: question.id,
      questionOrder: question.order,
      selectedOptionIndex: selectedOptionIndex,
      essayText: essayText,
      isAutoCorrect: isAuto,
      isCorrect: isCorrect,
      autoScore: autoScore,
      manualScore: 0,
      teacherFeedback: null,
      answeredAt: DateTime.now(),
      timeExpired: timeExpired,
    );

    final existing = await _firestore
        .collection(_answersCollection)
        .where('attemptId', isEqualTo: attempt.id)
        .where('questionId', isEqualTo: question.id)
        .limit(1)
        .get();
    if (existing.docs.isEmpty) {
      final docRef = await _firestore.collection(_answersCollection).add(answer.toMap());
      await docRef.update({'id': docRef.id});
    }

    final nextOrder = question.order + 1;
    await _firestore.collection(_attemptsCollection).doc(attempt.id).update({
      'currentQuestionOrder': nextOrder,
    });
  }

  Future<bool> examHasFinishedAttempts(String examId) async {
    final list = await getExamAttemptsForTeacher(examId);
    return list.any((a) => a.isFinished);
  }

  Future<void> finishAttempt(ExamAttemptModel attempt) async {
    final attemptRef = _firestore.collection(_attemptsCollection).doc(attempt.id);
    final beforeSnap = await attemptRef.get();
    final beforeData = beforeSnap.data();
    final wasAlreadyFinished = beforeData?['isFinished'] == true;
    final xpAlready = beforeData?['xpAwarded'] == true;

    final questions = await getExamQuestions(attempt.examId);
    final qMap = {for (final q in questions) q.id: q};
    final exam = await getExamById(attempt.examId);

    final answers = await _firestore
        .collection(_answersCollection)
        .where('attemptId', isEqualTo: attempt.id)
        .get();
    int scoreAuto = 0;
    int scoreManual = 0;
    for (final doc in answers.docs) {
      final a = ExamAttemptAnswerModel.fromMap(doc.data());
      scoreAuto += a.autoScore;
      int manual = a.manualScore;
      if (!a.isAutoCorrect) {
        final q = qMap[a.questionId];
        if (q != null) {
          final answerText = (a.essayText ?? '').trim();
          String rubric = (q.rubric ?? '').trim();
          int essayMax = q.maxPoints;
          if (q.isTrueFalse && q.justifyIfStatementFalse && q.correctIsTrue == false) {
            essayMax = q.justificationPoints > 0 ? q.justificationPoints : 0;
            final ref = (q.expectedJustification ?? '').trim();
            final jr = (q.justificationRubric ?? '').trim();
            final base = rubric;
            final parts = <String>[
              'قيّم تعليل الطالب بمقارنته بالتصحيح/التعليل المرجعي من المعلم. '
                  'امنح درجة عالية عند تطابق المعنى والأفكار الأساسية، وخفّض عند الغموض أو الخطأ المادّي.',
              if (ref.isNotEmpty) 'التصحيح المرجعي من المعلم:\n$ref',
              if (jr.isNotEmpty) 'معايير إضافية من المعلم:\n$jr',
              if (jr.isEmpty && base.isNotEmpty) 'سلم عام:\n$base',
            ];
            rubric = parts.where((s) => s.trim().isNotEmpty).join('\n\n').trim();
          }
          final tfJustifyOk = !q.isTrueFalse ||
              !q.justifyIfStatementFalse ||
              q.correctIsTrue != false ||
              a.isCorrect == true;
          if (rubric.isNotEmpty &&
              answerText.isNotEmpty &&
              essayMax > 0 &&
              tfJustifyOk) {
            final graded = await _aiService.gradeEssayAnswer(
              subject: exam?.subject ?? '',
              question: q.text,
              rubric: rubric,
              maxPoints: essayMax,
              studentAnswer: answerText,
            );
            manual = (graded['score'] as int?) ?? 0;
            await _firestore.collection(_answersCollection).doc(a.id).update({
              'manualScore': manual,
              'teacherFeedback': graded['feedback'] ?? '',
            });
          }
        }
      }
      scoreManual += manual;
    }

    final scoreFinal = scoreAuto + scoreManual;
    await attemptRef.update({
      'isFinished': true,
      'finishedAt': DateTime.now().toIso8601String(),
      'scoreAuto': scoreAuto,
      'scoreManual': scoreManual,
      'scoreFinal': scoreFinal,
    });

    // مكافأة XP مثل تصحيح الواجب: 5 + نقاط المحصلة (مرة واحدة)
    if (!wasAlreadyFinished && !xpAlready) {
      try {
        await _userService.addXP(attempt.studentId, 5 + scoreFinal);
        await attemptRef.update({'xpAwarded': true});
      } catch (e) {
        debugPrint('Exam finishAttempt addXP error: $e');
      }
    }
  }

  Future<int> getExamTotalPoints(String examId) async {
    final questions = await getExamQuestions(examId);
    int total = 0;
    for (final q in questions) {
      total += q.maxPoints;
    }
    return total;
  }

  Future<List<ExamAttemptAnswerModel>> getAttemptAnswers(String attemptId) async {
    final snapshot = await _firestore
        .collection(_answersCollection)
        .where('attemptId', isEqualTo: attemptId)
        .get();
    final answers = snapshot.docs.map((d) => ExamAttemptAnswerModel.fromMap(d.data())).toList();
    answers.sort((a, b) => a.questionOrder.compareTo(b.questionOrder));
    return answers;
  }

  Future<List<ExamAttemptModel>> getExamAttemptsForTeacher(String examId) async {
    final snapshot = await _firestore
        .collection(_attemptsCollection)
        .where('examId', isEqualTo: examId)
        .get();
    return snapshot.docs.map((d) => ExamAttemptModel.fromMap(d.data())).toList();
  }

  Future<List<ExamAttemptModel>> getStudentFinishedAttempts(String studentId) async {
    final snapshot = await _firestore
        .collection(_attemptsCollection)
        .where('studentId', isEqualTo: studentId)
        .get();
    final attempts = snapshot.docs.map((d) => ExamAttemptModel.fromMap(d.data())).toList();
    return attempts.where((a) => a.isFinished).toList();
  }

  Future<void> gradeEssayAnswer({
    required String answerId,
    required int score,
    required String feedback,
  }) async {
    await _firestore.collection(_answersCollection).doc(answerId).update({
      'manualScore': score,
      'teacherFeedback': feedback,
    });
  }

  Future<Map<String, String>> getStudentNamesForAttempts(List<ExamAttemptModel> attempts) async {
    final Map<String, String> names = {};
    for (final a in attempts) {
      final UserModel? user = await _userService.getUserProfile(a.studentId);
      names[a.studentId] = user?.name ?? 'طالب';
    }
    return names;
  }

  Future<List<String>> getStudentIdsForExam(ExamModel exam) async {
    final ids = <String>[];
    for (final classId in exam.classIds) {
      final ClassModel? classModel = await _classService.getClassById(classId);
      if (classModel == null) continue;
      for (final code in classModel.studentCodes) {
        final student = await _userService.getUserByStudentCode(code);
        if (student != null && !ids.contains(student.uid)) {
          ids.add(student.uid);
        }
      }
    }
    return ids;
  }

  Future<void> deleteExam(String examId) async {
    // Delete questions subcollection first, then exam doc
    final questionsRef = _firestore.collection(_examsCollection).doc(examId).collection('questions');
    final questions = await questionsRef.get();
    final batch = _firestore.batch();
    for (final doc in questions.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection(_examsCollection).doc(examId));
    await batch.commit();
  }
}
