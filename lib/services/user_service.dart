import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

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
