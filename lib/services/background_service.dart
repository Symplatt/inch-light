import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // 创建通知渠道
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'inch_light_timer',
    '专注计时服务',
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
      onStart: onStart, // 指定入口函数
      autoStart: false, // 【重要】设为 false，由我们代码手动控制启动
      isForegroundMode: true,
      notificationChannelId: 'inch_light_timer',
      initialNotificationTitle: '寸光',
      initialNotificationContent: '服务正在启动...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
  );
}

// 【必须】这是一个顶级函数，不能写在类里面
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // 【必须】确保插件在后台隔离区也能工作
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // 简单的保活计时器
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // 这里只更新通知，不要做复杂的逻辑
        service.setForegroundNotificationInfo(title: "寸光", content: "专注进行中...");
      }
    }
  });
}
