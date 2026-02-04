import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload assignment image
  Future<String> uploadAssignmentImage(File imageFile, String assignmentId) async {
    try {
      String fileName = 'assignments/$assignmentId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child(fileName);

      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading assignment image: $e');
      throw 'حدث خطأ أثناء رفع صورة الواجب: $e';
    }
  }

  // Upload submission image
  Future<String> uploadSubmissionImage(File imageFile, String submissionId) async {
    try {
      String fileName = 'submissions/$submissionId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child(fileName);

      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading submission image: $e');
      throw 'حدث خطأ أثناء رفع صورة الحل: $e';
    }
  }

  // Delete image
  Future<void> deleteImage(String imageUrl) async {
    try {
      Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting image: $e');
      // Don't throw error, just log it
    }
  }
}
