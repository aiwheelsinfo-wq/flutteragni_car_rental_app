import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.instance.setupFlutterNotifications();
  await NotificationService.instance.showNotification(message);
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isFlutterLocalNotificationsInitialized = false;

  Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 1. Set up high-importance Android Notification Channel immediately
      await setupFlutterNotifications();

      // 2. Request notification permissions
      await _requestPermission();

      // 3. Set up foreground and tap listeners
      await _setupMessageHandlers();

      // 4. Fetch FCM token with safe timeout
      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      print('FCM Token: $token');
    } catch (e) {
      print('Notification Service Init Error: $e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );
    print('Permission status: ${settings.authorizationStatus}');
  }

  Future<void> setupFlutterNotifications() async {
    if (_isFlutterLocalNotificationsInitialized) return;

    // Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings (no onDidReceiveLocalNotification)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    // Combine settings for both platforms
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // Initialize local notifications
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        print("Notification clicked: ${details.payload}");
      },
    );

    _isFlutterLocalNotificationsInitialized = true;
  }

  Future<void> showNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    String? title = notification?.title ?? message.data['title'];
    String? body = notification?.body ?? message.data['body'];

    if (title != null && title.isNotEmpty) {
      await _localNotifications.show(
        message.hashCode,
        title,
        body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['id']?.toString(),
      );
    }
  }

  Future<void> _setupMessageHandlers() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }
  }

  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    if (message.data['type'] == 'chat') {
      // Handle chat notification tap
    }
  }
}
