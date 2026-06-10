import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message received: ${message.messageId}');
  // Handle background message here
}

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _initialized = false;
  String? _fcmToken;

  // Initialize the service
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚠️ PushNotificationService already initialized');
      return;
    }

    try {
      // Only initialize on Android
      if (!Platform.isAndroid) {
        debugPrint('⚠️ Push notifications only supported on Android');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permissions
      await _requestPermissions();

      // Initialize FCM
      await _initializeFCM();

      // Get and save FCM token
      await _getFCMToken();

      _initialized = true;
      debugPrint('✅ PushNotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing PushNotificationService: $e');
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    // Initialize timezone data
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  // Create Android notification channels
  Future<void> _createNotificationChannels() async {
    // High priority channel (deadlines, level up)
    const AndroidNotificationChannel highPriorityChannel =
        AndroidNotificationChannel(
      'high_priority_channel',
      'إشعارات مهمة',
      description: 'إشعارات المواعيد النهائية والمستويات',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Default priority channel (assignments, submissions)
    const AndroidNotificationChannel defaultPriorityChannel =
        AndroidNotificationChannel(
      'default_priority_channel',
      'إشعارات عادية',
      description: 'إشعارات الواجبات والتسليمات',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    );

    // Low priority channel (reminders, streaks)
    const AndroidNotificationChannel lowPriorityChannel =
        AndroidNotificationChannel(
      'low_priority_channel',
      'تذكيرات',
      description: 'تذكيرات السلسلة والتذكيرات اليومية',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(highPriorityChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(defaultPriorityChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(lowPriorityChannel);
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Request permission for Android 13+
      final NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('📱 Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permission granted');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('⚠️ Notification permission granted provisionally');
      } else {
        debugPrint('❌ Notification permission denied');
      }
    }
  }

  // Initialize FCM
  Future<void> _initializeFCM() async {
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  // Get FCM token and save to Firestore
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('📱 FCM Token: $_fcmToken');

      // Save token to Firestore (will be updated when user logs in)
      // Token will be saved in UserService when user is authenticated

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        _fcmToken = newToken;
        _saveTokenToFirestore(newToken);
      });
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token, {String? userId}) async {
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
      });
      debugPrint('✅ FCM token saved to Firestore for user: $userId');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  // Save FCM token for current user
  Future<void> saveTokenForUser(String userId) async {
    if (_fcmToken == null) {
      try {
        _fcmToken = await _firebaseMessaging.getToken();
      } catch (e) {
        debugPrint('❌ saveTokenForUser: could not get FCM token: $e');
        return;
      }
    }
    if (_fcmToken != null) {
      await _saveTokenToFirestore(_fcmToken!, userId: userId);
    }
  }

  // Remove FCM token on logout
  Future<void> removeTokenForUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });
      debugPrint('✅ FCM token removed for user: $userId');
    } catch (e) {
      debugPrint('❌ Error removing FCM token: $e');
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message received: ${message.messageId}');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');

    // Show local notification when app is in foreground
    _showLocalNotification(
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      payload: message.data['actionType'],
      priority: message.data['priority'] ?? 'default',
    );
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.messageId}');
    debugPrint('   Data: ${message.data}');

    // Handle navigation based on notification type
    // Navigation will be handled by the app's navigation system
    // This is a placeholder - actual navigation should be implemented in the app
    // Access actionType and assignmentId via message.data['actionType'] and message.data['assignmentId']
  }

  // Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.payload}');
    // Handle navigation based on payload
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String priority = 'default',
  }) async {
    // Determine notification channel based on priority
    String channelId = 'default_priority_channel';
    String channelName = 'إشعارات عادية';
    Importance importance = Importance.defaultImportance;
    Priority priorityLevel = Priority.defaultPriority;

    if (priority == 'high') {
      channelId = 'high_priority_channel';
      channelName = 'إشعارات مهمة';
      importance = Importance.high;
      priorityLevel = Priority.high;
    } else if (priority == 'low') {
      channelId = 'low_priority_channel';
      channelName = 'تذكيرات';
      importance = Importance.low;
      priorityLevel = Priority.low;
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: priority == 'high'
          ? 'إشعارات المواعيد النهائية والمستويات'
          : priority == 'low'
              ? 'تذكيرات السلسلة والتذكيرات اليومية'
              : 'إشعارات الواجبات والتسليمات',
      importance: importance,
      priority: priorityLevel,
      showWhen: true,
      enableVibration: priority != 'low',
      playSound: priority != 'low',
    );

    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Send push notification via FCM (for server-side use)
  // This method is for reference - actual sending should be done via Cloud Functions
  Future<void> sendPushNotification({
    required String fcmToken,
    required String title,
    required String body,
    String? actionType,
    String? assignmentId,
    String priority = 'default',
  }) async {
    // Note: This is a placeholder
    // Actual FCM sending should be done via Cloud Functions or Admin SDK
    // This method is here for reference only
    debugPrint('📤 Would send push notification to: $fcmToken');
    debugPrint('   Title: $title');
    debugPrint('   Body: $body');
  }

  // Schedule local notification for deadline
  Future<void> scheduleDeadlineNotification({
    required int notificationId,
    required DateTime scheduledDate,
    required String title,
    required String body,
    String? payload,
  }) async {
    final location = tz.getLocation('Asia/Riyadh');
    final tz.TZDateTime scheduledDateTime = tz.TZDateTime.from(
      scheduledDate,
      location,
    );

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'high_priority_channel',
      'إشعارات مهمة',
      channelDescription: 'إشعارات المواعيد النهائية',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDateTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    debugPrint('⏰ Scheduled notification for: $scheduledDate');
  }

  // Cancel scheduled notification
  Future<void> cancelScheduledNotification(int notificationId) async {
    await _localNotifications.cancel(notificationId);
    debugPrint('❌ Cancelled notification: $notificationId');
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    debugPrint('❌ Cancelled all notifications');
  }

  // Get FCM token
  String? get fcmToken => _fcmToken;

  // Check if initialized
  bool get isInitialized => _initialized;
}
