import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/class_model.dart';

class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'classes';

  // Create a new class
  Future<String> createClass(ClassModel classModel) async {
    try {
      DocumentReference docRef = await _firestore.collection(_collection).add(classModel.toMap());
      // Update the class with its ID
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating class: $e');
      throw 'حدث خطأ أثناء إنشاء الصف: $e';
    }
  }

  // Get all classes for a teacher
  Future<List<ClassModel>> getTeacherClasses(String teacherId) async {
    try {
      // First try with orderBy
      try {
        QuerySnapshot querySnapshot = await _firestore
            .collection(_collection)
            .where('teacherId', isEqualTo: teacherId)
            .orderBy('createdAt', descending: true)
            .get();

        List<ClassModel> classes = querySnapshot.docs
            .map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              // Ensure ID is set
              data['id'] = doc.id;
              return ClassModel.fromMap(data);
            })
            .toList();
        
        debugPrint('✅ Found ${classes.length} classes for teacher $teacherId');
        return classes;
      } catch (e) {
        // If orderBy fails (no index), try without orderBy
        debugPrint('⚠️ OrderBy failed, trying without orderBy: $e');
        QuerySnapshot querySnapshot = await _firestore
            .collection(_collection)
            .where('teacherId', isEqualTo: teacherId)
            .get();

        List<ClassModel> classes = querySnapshot.docs
            .map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return ClassModel.fromMap(data);
            })
            .toList();
        
        // Sort manually
        classes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        debugPrint('✅ Found ${classes.length} classes for teacher $teacherId (without orderBy)');
        return classes;
      }
    } catch (e) {
      debugPrint('❌ Error getting teacher classes: $e');
      throw 'حدث خطأ أثناء جلب الصفوف: $e';
    }
  }

  // Get class by ID
  Future<ClassModel?> getClassById(String classId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(classId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Ensure ID is set
        return ClassModel.fromMap(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting class: $e');
      throw 'حدث خطأ أثناء جلب الصف: $e';
    }
  }

  // Update class (add/remove students)
  Future<void> updateClass(String classId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(_collection).doc(classId).update(data);
    } catch (e) {
      debugPrint('Error updating class: $e');
      throw 'حدث خطأ أثناء تحديث الصف: $e';
    }
  }

  // Add student to class
  Future<void> addStudentToClass(String classId, String studentCode) async {
    try {
      ClassModel? classModel = await getClassById(classId);
      if (classModel == null) {
        throw 'الصف غير موجود';
      }

      if (!classModel.studentCodes.contains(studentCode)) {
        List<String> updatedCodes = List.from(classModel.studentCodes)..add(studentCode);
        await updateClass(classId, {'studentCodes': updatedCodes});
      }
    } catch (e) {
      debugPrint('Error adding student to class: $e');
      throw e.toString();
    }
  }

  // Remove student from class
  Future<void> removeStudentFromClass(String classId, String studentCode) async {
    try {
      ClassModel? classModel = await getClassById(classId);
      if (classModel == null) {
        throw 'الصف غير موجود';
      }

      List<String> updatedCodes = List.from(classModel.studentCodes)..remove(studentCode);
      await updateClass(classId, {'studentCodes': updatedCodes});
    } catch (e) {
      debugPrint('Error removing student from class: $e');
      throw e.toString();
    }
  }

  // Delete class
  Future<void> deleteClass(String classId) async {
    try {
      await _firestore.collection(_collection).doc(classId).delete();
    } catch (e) {
      debugPrint('Error deleting class: $e');
      throw 'حدث خطأ أثناء حذف الصف: $e';
    }
  }
}
