import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'notification_service.dart';

const String kBackgroundNotificationChannelId =
    'credit_aging_background_service';

const int kBackgroundServiceNotificationId = 9001;

Future<void> configureBackgroundMonitoring() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    kBackgroundNotificationChannelId,
    'Credit Aging background monitoring',
    description:
        'Keeps Credit Aging monitoring active in the background.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: backgroundServiceEntryPoint,

      // We manually start the service after login.
      autoStart: false,

      // Allows Android to restart the service after reboot.
      autoStartOnBoot: true,

      // Required because this is a foreground service.
      isForegroundMode: true,

      notificationChannelId: kBackgroundNotificationChannelId,

      initialNotificationTitle: 'Credit Aging',

      initialNotificationContent: 'Monitoring new requests',

      foregroundServiceNotificationId:
          kBackgroundServiceNotificationId,

      // Android 14+ requires the foreground service type
      // to match the manifest declaration.
      foregroundServiceTypes: const [
        AndroidForegroundType.dataSync,
      ],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: backgroundServiceEntryPoint,
      onBackground: iosBackgroundEntryPoint,
    ),
  );
}

Future<void> startBackgroundMonitoring() async {
  final FlutterBackgroundService service =
      FlutterBackgroundService();

  final bool running = await service.isRunning();

  if (!running) {
    await service.startService();
  }
}

Future<void> stopBackgroundMonitoring() async {
  final FlutterBackgroundService service =
      FlutterBackgroundService();

  final bool running = await service.isRunning();

  if (running) {
    service.invoke('stopService');
  }
}

Future<void> setAppInForeground(bool value) async {
  FlutterBackgroundService().invoke(
    'appLifecycle',
    <String, dynamic>{
      'foreground': value,
    },
  );
}

@pragma('vm:entry-point')
void backgroundServiceEntryPoint(
  ServiceInstance service,
) async {
  DartPluginRegistrant.ensureInitialized();

  await GetStorage.init();

  await NotificationService.initialize(
    requestPermission: false,
  );

  // If Android automatically starts the service after reboot
  // but the user is no longer logged in, stop the service.
  if (!AuthService.isLoggedIn) {
    service.stopSelf();
    return;
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  bool appInForeground = false;
  bool polling = false;

  Timer? pollTimer;

  service.on('stopService').listen((event) {
    pollTimer?.cancel();
    pollTimer = null;

    service.stopSelf();
  });

  service.on('appLifecycle').listen((event) {
    if (event != null) {
      appInForeground = event['foreground'] == true;
    }
  });

  final ApiService api = ApiService();

  Future<void> poll() async {
    if (polling) return;

    if (appInForeground) return;

    if (!AuthService.isLoggedIn) {
      pollTimer?.cancel();
      pollTimer = null;

      service.stopSelf();
      return;
    }

    polling = true;

    try {
      final requests = await api.getCreditAgingRequests();

      await NotificationService.syncRequests(requests);
    } catch (_) {
      // Never allow a temporary API/network failure
      // to terminate the background service.
    } finally {
      polling = false;
    }
  }

  // Run immediately.
  await poll();

  // Poll every 5 seconds.
  pollTimer?.cancel();

  pollTimer = Timer.periodic(
    const Duration(seconds: 5),
    (_) {
      poll();
    },
  );
}

@pragma('vm:entry-point')
Future<bool> iosBackgroundEntryPoint(
  ServiceInstance service,
) async {
  DartPluginRegistrant.ensureInitialized();

  await GetStorage.init();

  await NotificationService.initialize(
    requestPermission: false,
  );

  return true;
}

