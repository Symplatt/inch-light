import 'dart:async';
import 'dart:ui';
// import 'package:flutter/material.dart'; // 没用上
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 初始化服务
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'inch_light_timer', // id
    '专注计时服务', // title
    description: '保持专注计时在后台运行',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // 不自动启动，由 TimerPage 控制
      isForegroundMode: true,
      notificationChannelId: 'inch_light_timer',
      initialNotificationTitle: '寸光',
      initialNotificationContent: '专注进行中...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // 这里可以写更复杂的逻辑，简单起见，我们只用它来保活
  // 实际的计时逻辑依然由 AppProvider 的 Time.periodic 负责
  // 因为 Wakelock + 前台服务 notification 已经足够防止 App 被杀
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // 可选：在这里更新通知栏显示倒计时剩余时间
        // 需要通过 invoke 通信获取当前时间，略复杂，这里仅做保活
        service.setForegroundNotificationInfo(
          title: "寸光",
          content: "正在专注中，请保持...",
        );
      }
    }
  });
}
