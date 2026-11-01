import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'backend_service.dart';

const firebaseDefaultOptions = FirebaseOptions(
  apiKey: 'AIzaSyAuu7g-DHE6cqMGUz-n5DMGhp0gh9acx70',
  appId: '1:821177840242:android:d54600a59b3d83e5a0c8eb',
  messagingSenderId: '821177840242',
  projectId: 'eligiblecrmdatabase',
  databaseURL: 'https://eligiblecrmdatabase-default-rtdb.firebaseio.com',
  storageBucket: 'eligiblecrmdatabase.firebasestorage.app',
);

/// Background message handler for FCM (runs in separate isolate when app is closed / background)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: firebaseDefaultOptions);
    }
  } catch (_) {}
  debugPrint('🌙 [FCM Background] Received message: ${message.messageId} | ${message.notification?.title}');
}

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._internal();
  PushNotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _adminLeadsChannel = AndroidNotificationChannel(
    'admin_leads_channel',
    'Admin Lead Alerts',
    description: 'Instant high-priority alerts for new incoming leads in database',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static final AndroidNotificationChannel _followupRemindersChannel = AndroidNotificationChannel(
    'followup_reminders_channel_v2',
    'Follow-up Reminders (2s Vibrate)',
    description: 'Instant reminders for scheduled customer follow-ups with 2-second vibration',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 2000]),
  );

  bool _initialized = false;
  Completer<void>? _initCompleter;
  String? _cachedFcmToken;
  String? get fcmToken => _cachedFcmToken;

  /// Initialize Firebase & Local Notifications
  Future<void> initialize() async {
    if (_initialized) return;
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    _initCompleter = Completer<void>();

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: firebaseDefaultOptions);
      }

      // 1. Background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 2. Request notification permissions (Android 13+ & iOS)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );
      debugPrint('🔔 [PushNotificationService] Permission authorization status: ${settings.authorizationStatus}');

      // 3. Foreground presentation options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Create Android high priority notification channel
      final androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_adminLeadsChannel);
        await androidImplementation.createNotificationChannel(_followupRemindersChannel);
      }

      // 5. Initialize flutter_local_notifications for heads-up foreground banners
      tz.initializeTimeZones();
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotifications.initialize(settings: initSettings);

      // 6. Listen for incoming messages while app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('☀️ [FCM Foreground] Message received: ${message.notification?.title}');
        _showForegroundNotification(message);
      });

      // 7. Get initial real hardware FCM token
      try {
        _cachedFcmToken = await _fcm.getToken();
        debugPrint('🔑 [PushNotificationService] Real FCM Token: $_cachedFcmToken');
      } catch (tokenErr) {
        debugPrint('⚠️ [PushNotificationService] Could not retrieve FCM token: $tokenErr');
      }

      _initialized = true;
      _initCompleter?.complete();
    } catch (e) {
      debugPrint('❌ [PushNotificationService] Initialization error: $e');
      _initCompleter?.complete();
      _initCompleter = null;
    }
  }

  final Set<String> _processedLeadIds = <String>{};

  /// Show heads-up notification banner when message arrives while app is open
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Deduplication check: extract unique lead identifier or payload signature
    final leadId = message.data['leadId']?.toString().trim();
    final dedupeKey = (leadId != null && leadId.isNotEmpty)
        ? leadId
        : '${notification.title}_${notification.body}';

    // Discard if duplicate message arrives within sliding 30-second window
    if (_processedLeadIds.contains(dedupeKey)) {
      debugPrint('🛡️ [PushNotificationService] Discarding duplicate lead alert for: $dedupeKey');
      return;
    }

    _processedLeadIds.add(dedupeKey);
    Timer(const Duration(seconds: 30), () {
      _processedLeadIds.remove(dedupeKey);
    });

    // Deterministic notification ID so Android replaces instead of duplicating
    final int notifId = dedupeKey.hashCode.abs() % 100000;

    final androidDetails = AndroidNotificationDetails(
      _adminLeadsChannel.id,
      _adminLeadsChannel.name,
      channelDescription: _adminLeadsChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      tag: 'lead_$dedupeKey',
      onlyAlertOnce: true,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications.show(
      id: notifId,
      title: notification.title ?? 'New Lead Arrived',
      body: notification.body ?? 'A new lead has been submitted',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: message.data.toString(),
    );
  }

  /// Trigger a follow-up reminder notification with 2-second vibration for agent
  Future<void> showFollowupReminderNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _followupRemindersChannel.id,
      _followupRemindersChannel.name,
      channelDescription: _followupRemindersChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 2000]), // 2-second continuous vibration
      fullScreenIntent: true,
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  /// Schedule a follow-up reminder at an exact date and time with 2-second continuous vibration
  Future<void> scheduleFollowupNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      final now = DateTime.now();
      // If scheduled time is immediate or in the past, trigger now
      if (scheduledDate.isBefore(now.add(const Duration(seconds: 5)))) {
        await showFollowupReminderNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        );
        return;
      }

      final androidDetails = AndroidNotificationDetails(
        _followupRemindersChannel.id,
        _followupRemindersChannel.name,
        channelDescription: _followupRemindersChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 2000]), // 2-second continuous vibration
        fullScreenIntent: true,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(body),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

      await _localNotifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDateTime,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      debugPrint('⏰ [PushNotificationService] Scheduled reminder #$id at $scheduledDate (2s vibration)');
    } catch (e) {
      debugPrint('⚠️ [PushNotificationService] Error scheduling notification: $e');
      // If zonedSchedule has any platform restriction, fallback to in-memory timer if within current session
      final delay = scheduledDate.difference(DateTime.now());
      if (!delay.isNegative && delay.inHours < 24) {
        Timer(delay, () {
          showFollowupReminderNotification(
            id: id,
            title: title,
            body: body,
            payload: payload,
          );
        });
      }
    }
  }

  /// Cancel any scheduled or pending notification by id
  Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id: id);
      debugPrint('🗑️ [PushNotificationService] Cancelled notification #$id');
    } catch (e) {
      debugPrint('⚠️ [PushNotificationService] Error cancelling notification: $e');
    }
  }

  /// Register user device with backend, targeting admin specifically for lead alerts
  Future<void> syncUserSession({
    required String userId,
    required String userName,
    required bool isAdmin,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // Retrieve or refresh token
      _cachedFcmToken ??= await _fcm.getToken();

      if (isAdmin) {
        // Subscribe to admin lead alerts topic
        await _fcm.subscribeToTopic('admin_leads');
        debugPrint('✅ [PushNotificationService] Subscribed to topic: admin_leads');
      } else {
        await _fcm.unsubscribeFromTopic('admin_leads');
      }

      if (_cachedFcmToken != null && _cachedFcmToken!.isNotEmpty) {
        // Send real device token to backend
        await BackendService().registerFcmToken(
          userId: userId,
          name: userName,
          role: isAdmin ? 'admin' : 'sales_agent',
          token: _cachedFcmToken!,
          deviceName: 'Android Device (${isAdmin ? 'Admin' : 'Sales'})',
          platform: 'android',
        );
        debugPrint('✅ [PushNotificationService] Real FCM token registered with backend for $userName ($userId)');
      }

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        _cachedFcmToken = newToken;
        BackendService().registerFcmToken(
          userId: userId,
          name: userName,
          role: isAdmin ? 'admin' : 'sales_agent',
          token: newToken,
          deviceName: 'Android Device (${isAdmin ? 'Admin' : 'Sales'})',
          platform: 'android',
        );
      });
    } catch (e) {
      debugPrint('⚠️ [PushNotificationService] syncUserSession error: $e');
    }
  }
}
