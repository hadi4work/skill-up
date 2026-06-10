import 'package:shared_preferences/shared_preferences.dart';

/// تتبع ما شاهده الطالب من واجبات واختبارات/وظائف مؤقتة (لإخفاء نقطة التنبيه الحمراء).
class StudentContentSeenService {
  static String _assignmentsKey(String uid) => 'student_seen_assignment_ids_v1_$uid';
  static String _timedExamsKey(String uid) => 'student_seen_timed_exam_ids_v1_$uid';
  static String _timedWorkKey(String uid) => 'student_seen_timed_work_ids_v1_$uid';

  static Future<Set<String>> _readIds(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key);
    if (list == null) return {};
    return list.where((e) => e.isNotEmpty).toSet();
  }

  static Future<void> _mergeIds(String key, Iterable<String> ids) async {
    final filtered = ids.where((e) => e.isNotEmpty).toList();
    if (filtered.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final cur = (prefs.getStringList(key) ?? []).toSet();
    cur.addAll(filtered);
    await prefs.setStringList(key, cur.toList());
  }

  static Future<void> markAssignmentSeen(String uid, String assignmentId) async {
    if (uid.isEmpty || assignmentId.isEmpty) return;
    await _mergeIds(_assignmentsKey(uid), [assignmentId]);
  }

  static Future<void> markTimedExamsSeen(String uid, Iterable<String> examIds) async {
    if (uid.isEmpty) return;
    await _mergeIds(_timedExamsKey(uid), examIds);
  }

  static Future<void> markTimedAssignmentsSeen(String uid, Iterable<String> examIds) async {
    if (uid.isEmpty) return;
    await _mergeIds(_timedWorkKey(uid), examIds);
  }

  static Future<bool> hasUnseenAssignments(
    String uid,
    Iterable<String> assignmentIds,
  ) async {
    if (uid.isEmpty) return false;
    final ids = assignmentIds.where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return false;
    final seen = await _readIds(_assignmentsKey(uid));
    return ids.any((id) => !seen.contains(id));
  }

  static Future<bool> hasUnseenTimedExams(String uid, Iterable<String> availableExamIds) async {
    if (uid.isEmpty) return false;
    final ids = availableExamIds.where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return false;
    final seen = await _readIds(_timedExamsKey(uid));
    return ids.any((id) => !seen.contains(id));
  }

  static Future<bool> hasUnseenTimedAssignments(
    String uid,
    Iterable<String> availableIds,
  ) async {
    if (uid.isEmpty) return false;
    final ids = availableIds.where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return false;
    final seen = await _readIds(_timedWorkKey(uid));
    return ids.any((id) => !seen.contains(id));
  }
}
