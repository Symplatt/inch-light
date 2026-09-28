import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'constants/app_colors.dart';
import 'providers/app_provider.dart';
import 'screens/main_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 必须调用

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // 申请通知权限
  void _requestPermissions() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await Permission.notification.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '一日千录',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
          onSurface: AppColors.textDark,
          error: AppColors.danger,
        ),
        // textTheme: GoogleFonts.notoSansScTextTheme(),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
