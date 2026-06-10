import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class MistakeTrainingSessionResult {
  final int gainedXP;
  final int streakDays;
  final bool streakIncreased;
  final int newTotalXP;
  final int newLevel;

  const MistakeTrainingSessionResult({
    required this.gainedXP,
    required this.streakDays,
    required this.streakIncreased,
    required this.newTotalXP,
    required this.newLevel,
  });
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // Create user profile
  Future<void> createUserProfile(UserModel user) async {
    try {
      debugPrint('📝 Attempting to save user to Firestore...');
      debugPrint('   UID: ${user.uid}');
      debugPrint('   Name: ${user.name}');
      debugPrint('   Email: ${user.email}');
      debugPrint('   Account Type: ${user.accountType}');
      
      Map<String, dynamic> userData = user.toMap();
      debugPrint('   Data to save: $userData');
      
      await _firestore.collection(_collection).doc(user.uid).set(userData);
      
      debugPrint('✅ User profile saved successfully to Firestore');
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase error saving user: ${e.code} - ${e.message}');
      throw 'حدث خطأ في Firebase: ${e.message ?? e.code}';
    } catch (e) {
      debugPrint('❌ Error saving user to Firestore: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      throw 'حدث خطأ أثناء إنشاء ملف المستخدم: $e';
    }
  }

  // Get user profile
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      debugPrint('📖 Fetching user profile for UID: $uid');
      DocumentSnapshot doc =
          await _firestore.collection(_collection).doc(uid).get();
      if (doc.exists) {
        debugPrint('✅ User profile found');
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      debugPrint('⚠️ User profile not found for UID: $uid');
      return null;
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase error fetching user: ${e.code} - ${e.message}');
      throw 'حدث خطأ في Firebase: ${e.message ?? e.code}';
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      throw 'حدث خطأ أثناء جلب ملف المستخدم: $e';
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(_collection).doc(uid).update(data);
    } catch (e) {
      throw 'حدث خطأ أثناء تحديث ملف المستخدم: $e';
    }
  }

  // Delete user profile with relation cleanup
  Future<void> deleteUserProfileAndRelations(UserModel user) async {
    try {
      final usersRef = _firestore.collection(_collection);

      if (user.accountType == 'student') {
        // If student has a parent, remove student code from parent's children list.
        if (user.parentId != null && user.parentId!.isNotEmpty) {
          final code = user.studentCode;
          if (code != null && code.isNotEmpty) {
            await usersRef.doc(user.parentId!).update({
              'children': FieldValue.arrayRemove([code]),
            }).catchError((_) {});
          }
        }
      } else if (user.accountType == 'parent') {
        // Unlink all linked children from this parent.
        for (final code in (user.children ?? <String>[])) {
          try {
            final student = await getUserByStudentCode(code);
            if (student != null && student.parentId == user.uid) {
              await usersRef.doc(student.uid).update({'parentId': null});
            }
          } catch (_) {}
        }
      }

      await usersRef.doc(user.uid).delete();
    } catch (e) {
      throw 'حدث خطأ أثناء حذف بيانات الحساب: $e';
    }
  }

  // Add XP to student and update level
  Future<void> addXP(String uid, int xpToAdd) async {
    try {
      UserModel? user = await getUserProfile(uid);
      if (user == null) {
        throw 'المستخدم غير موجود';
      }

      int newXP = user.xp + xpToAdd;
      int oldLevel = user.level;
      int newLevel = user.calculateLevel(newXP);

      // Update XP and level in Firestore
      await _firestore.collection(_collection).doc(uid).update({
        'xp': newXP,
        'level': newLevel,
      });

      debugPrint('✅ Added $xpToAdd XP to user $uid');
      debugPrint('   Old XP: ${user.xp}, New XP: $newXP');
      debugPrint('   Old Level: $oldLevel, New Level: $newLevel');

      // Check if level up occurred and send notification
      if (newLevel > oldLevel) {
        debugPrint('🎉 Level up! User $uid reached level $newLevel');
        
        // Send level up notification
        final NotificationService notificationService = NotificationService();
        await notificationService.sendLevelUpNotification(
          studentId: uid,
          newLevel: newLevel,
        );
      }
    } catch (e) {
      debugPrint('❌ Error adding XP: $e');
      throw 'حدث خطأ أثناء إضافة النقاط: $e';
    }
  }

  Future<MistakeTrainingSessionResult> recordMistakeTrainingSession({
    required String uid,
    required int totalQuestions,
    required int correctAnswers,
  }) async {
    try {
      final user = await getUserProfile(uid);
      if (user == null) throw 'المستخدم غير موجود';

      final int safeTotal = totalQuestions <= 0 ? 1 : totalQuestions;
      final int safeCorrect = correctAnswers.clamp(0, safeTotal);
      final double accuracy = safeCorrect / safeTotal;
      final int gainedXP = (5 + (safeCorrect * 2) + (accuracy >= 0.8 ? 3 : 0)).clamp(5, 40);

      final docRef = _firestore.collection(_collection).doc(uid);
      final doc = await docRef.get();
      final data = doc.data() ?? <String, dynamic>{};

      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      final DateTime? lastDate = _parseDateOnly(data['mistakeTrainingLastDate']);
      int streak = (data['mistakeTrainingStreakDays'] as num?)?.toInt() ?? 0;
      bool streakIncreased = false;

      if (lastDate == null) {
        streak = 1;
        streakIncreased = true;
      } else {
        final daysDiff = today.difference(lastDate).inDays;
        if (daysDiff == 0) {
          // نفس اليوم: لا زيادة ولا تصفير
        } else if (daysDiff == 1) {
          streak += 1;
          streakIncreased = true;
        } else {
          streak = 1;
          streakIncreased = true;
        }
      }

      final int newXP = user.xp + gainedXP;
      final int newLevel = user.calculateLevel(newXP);

      await docRef.update({
        'xp': newXP,
        'level': newLevel,
        'mistakeTrainingStreakDays': streak,
        'mistakeTrainingLastDate': today.toIso8601String(),
        'mistakeTrainingSessionsCount': FieldValue.increment(1),
        'mistakeTrainingTotalCorrect': FieldValue.increment(safeCorrect),
        'mistakeTrainingTotalQuestions': FieldValue.increment(safeTotal),
      });

      if (newLevel > user.level) {
        final notificationService = NotificationService();
        await notificationService.sendLevelUpNotification(
          studentId: uid,
          newLevel: newLevel,
        );
      }

      return MistakeTrainingSessionResult(
        gainedXP: gainedXP,
        streakDays: streak,
        streakIncreased: streakIncreased,
        newTotalXP: newXP,
        newLevel: newLevel,
      );
    } catch (e) {
      debugPrint('❌ Error recording mistake training session: $e');
      throw 'حدث خطأ أثناء حفظ جلسة التدريب: $e';
    }
  }

  /// قائمة عناصر تحتاج مراجعة (تتقل عند نجاح التدريب على كل عنصر).
  Future<List<Map<String, dynamic>>> getMistakeTrainingPending(String uid) async {
    final snap = await _firestore.collection(_collection).doc(uid).get();
    final raw = snap.data()?['mistakeTrainingPending'];
    if (raw is! List) return [];
    return raw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((m) => (m['id'] ?? '').toString().isNotEmpty)
        .toList();
  }

  /// مفاتيح عناصر أتقنها الطالب في التدريب — لا تُعاد إضافتها من [discover] بعد تسجيل الخروج/المزامنة.
  Future<Set<String>> getMistakeTrainingMasteredIds(String uid) async {
    final snap = await _firestore.collection(_collection).doc(uid).get();
    final raw = snap.data()?['mistakeTrainingMasteredIds'];
    if (raw is! List) return {};
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet();
  }

  /// دمج اكتشافات جديدة مع القائمة المحفوظة (بدون تكرار id). يبقي قائمة [mistakeTrainingPending]
  /// متسقة مع [mistakeTrainingMasteredIds] ولا يعيد العناصر المُتقنة رغم بقاء الخطأ في سجل الاختبار.
  Future<void> syncMistakeTrainingPending(
    String uid,
    List<Map<String, dynamic>> discovered,
  ) async {
    final ref = _firestore.collection(_collection).doc(uid);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      final masteredRaw = data['mistakeTrainingMasteredIds'];
      final mastered = masteredRaw is List
          ? masteredRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet()
          : <String>{};

      final existingRaw = data['mistakeTrainingPending'];
      var existing = existingRaw is List
          ? existingRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where((m) {
                final id = m['id']?.toString();
                return id != null && id.isNotEmpty && !mastered.contains(id);
              })
              .toList()
          : <Map<String, dynamic>>[];

      final ids = existing.map((e) => e['id']?.toString()).whereType<String>().toSet();

      for (final d in discovered) {
        final id = d['id']?.toString();
        if (id == null || id.isEmpty || mastered.contains(id)) continue;
        if (ids.contains(id)) continue;
        existing.add(Map<String, dynamic>.from(d));
        ids.add(id);
      }

      tx.update(ref, {'mistakeTrainingPending': existing});
    });
  }

  /// إزالة عناصر أتقنها الطالب في جلسة التدريب وتسجيلها حتى لا تُستعاد من الاكتشاف لاحقاً.
  Future<void> removeMistakeTrainingResolved(String uid, List<String> resolvedIds) async {
    if (resolvedIds.isEmpty) return;
    final idsUnion = resolvedIds.toSet().toList();
    final ref = _firestore.collection(_collection).doc(uid);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final removeSet = idsUnion.toSet();
      final existingRaw = snap.data()?['mistakeTrainingPending'];
      final existing = existingRaw is List
          ? existingRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      final filtered =
          existing.where((e) => !removeSet.contains(e['id']?.toString())).toList();
      tx.update(ref, {
        'mistakeTrainingPending': filtered,
        'mistakeTrainingMasteredIds': FieldValue.arrayUnion(idsUnion),
      });
    });
  }

  DateTime? _parseDateOnly(dynamic value) {
    if (value == null) return null;
    try {
      final d = DateTime.parse(value.toString());
      return DateTime(d.year, d.month, d.day);
    } catch (_) {
      return null;
    }
  }

  // Get user profile stream (for real-time updates)
  Stream<UserModel?> getUserProfileStream(String uid) {
    debugPrint('📡 Creating stream for user $uid');
    return _firestore
        .collection(_collection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        int xp = data['xp'] ?? 0;
        int storedLevel = data['level'] ?? 1;
        
        // Calculate correct level from XP
        UserModel tempUser = UserModel.fromMap(data);
        int calculatedLevel = tempUser.calculateLevel(xp);
        
        debugPrint('📥 Stream data received for $uid: XP=$xp, Stored Level=$storedLevel, Calculated Level=$calculatedLevel');
        
        // If level doesn't match XP, update it in Firestore
        if (storedLevel != calculatedLevel) {
          debugPrint('⚠️ Level mismatch detected! Updating level from $storedLevel to $calculatedLevel');
          // Update level in Firestore asynchronously (don't wait)
          _firestore.collection(_collection).doc(uid).update({
            'level': calculatedLevel,
          }).catchError((error) {
            debugPrint('❌ Error updating level: $error');
          });
        }
        
        // Return user with correct level
        return UserModel.fromMap(data).copyWith(level: calculatedLevel);
      }
      debugPrint('⚠️ Stream document does not exist for $uid');
      return null;
    });
  }

  // Add class to student
  Future<void> addClassToStudent(String uid, String classId) async {
    try {
      UserModel? user = await getUserProfile(uid);
      if (user == null) {
        throw 'المستخدم غير موجود';
      }

      List<String> classIds = List<String>.from(user.classIds ?? []);
      if (!classIds.contains(classId)) {
        classIds.add(classId);
        await _firestore.collection(_collection).doc(uid).update({
          'classIds': classIds,
        });
      }
    } catch (e) {
      throw 'حدث خطأ أثناء إضافة الصف: $e';
    }
  }

  // Get user by student code
  Future<UserModel?> getUserByStudentCode(String studentCode) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('studentCode', isEqualTo: studentCode)
          .where('accountType', isEqualTo: 'student')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromMap(
            querySnapshot.docs.first.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw 'حدث خطأ أثناء البحث عن الطالب: $e';
    }
  }

  // Generate unique student code
  Future<String> generateStudentCode() async {
    try {
      debugPrint('🔢 Generating student code...');
      String code = '';
      bool isUnique = false;
      int attempts = 0;
      const maxAttempts = 10;
      
      while (!isUnique && attempts < maxAttempts) {
        attempts++;
        // Generate 6-digit code
        final random = DateTime.now().millisecondsSinceEpoch % 900000;
        code = (100000 + random).toString();
        
        debugPrint('   Attempt $attempts: Generated code: $code');
        
        try {
          QuerySnapshot querySnapshot = await _firestore
              .collection(_collection)
              .where('studentCode', isEqualTo: code)
              .limit(1)
              .get();
          
          isUnique = querySnapshot.docs.isEmpty;
          
          if (isUnique) {
            debugPrint('✅ Unique student code generated: $code');
          } else {
            debugPrint('   Code $code already exists, trying again...');
            // Add small delay to ensure different timestamp
            await Future.delayed(const Duration(milliseconds: 10));
          }
        } catch (e) {
          debugPrint('   Error checking code uniqueness: $e');
          // If we can't check, assume it's unique and continue
          isUnique = true;
        }
      }
      
      if (!isUnique) {
        throw 'فشل في إنشاء كود طالب فريد بعد $maxAttempts محاولات';
      }
      
      return code;
    } catch (e) {
      debugPrint('❌ Error generating student code: $e');
      throw 'حدث خطأ أثناء إنشاء كود الطالب: $e';
    }
  }

  // Link parent to student
  Future<void> linkParentToStudent(String parentId, String studentCode) async {
    try {
      UserModel? student = await getUserByStudentCode(studentCode);
      if (student == null) {
        throw 'كود الطالب غير صحيح';
      }

      // Update student's parentId
      await updateUserProfile(student.uid, {'parentId': parentId});

      // Update parent's children list
      UserModel? parent = await getUserProfile(parentId);
      if (parent != null) {
        List<String> children = List<String>.from(parent.children ?? []);
        if (!children.contains(studentCode)) {
          children.add(studentCode);
          await updateUserProfile(parentId, {'children': children});
        }
      }
    } catch (e) {
      throw e.toString();
    }
  }
}
