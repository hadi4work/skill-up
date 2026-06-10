import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// يستدعي دالة Supabase لإرسال FCM (بدون Cloud Functions في Firebase).
class PushDispatchService {
  PushDispatchService._();
  static final PushDispatchService instance = PushDispatchService._();

  /// لا يرمي للأعلى؛ الإشعار في Firestore موجود حتى لو فشل الـ Push.
  Future<void> tryDispatchRemotePush({
    required String notificationId,
    required String userId,
    required String title,
    required String body,
    required String type,
    required String priority,
    String? actionType,
    String? assignmentId,
    Map<String, dynamic>? metadata,
  }) async {
    final secret = SupabaseConfig.pushDispatchSecret;
    if (secret.isEmpty) {
      debugPrint(
        'PushDispatch: ضع PUSH_DISPATCH_SECRET (--dart-define) لتفعيل الإشعارات عبر Supabase',
      );
      return;
    }

    try {
      final payload = <String, dynamic>{
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'priority': priority,
        'notificationId': notificationId,
        if (actionType != null && actionType.isNotEmpty) 'actionType': actionType,
        if (assignmentId != null && assignmentId.isNotEmpty)
          'assignmentId': assignmentId,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      };

      final response = await Supabase.instance.client.functions.invoke(
        'send-fcm-push',
        body: payload,
        headers: {'x-push-secret': secret},
      );

      if (response.status != 200) {
        debugPrint(
          'PushDispatch: status ${response.status} data: ${response.data}',
        );
      } else {
        debugPrint('PushDispatch: ok ${response.data}');
      }
    } catch (e, st) {
      debugPrint('PushDispatch error: $e\n$st');
    }
  }
}
