import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/supabase_service.dart';
import 'services/collection_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_nav_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 상태바 스타일 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Supabase 클라우드 서비스 초기화
  await SupabaseService.initialize();

  // 로컬 수집 도감 서비스 초기화
  await CollectionService.initialize();

  runApp(const StampKoreaApp());
}

class StampKoreaApp extends StatelessWidget {
  const StampKoreaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '우표모아 (StampKorea)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.light,
      home: const SplashScreen(child: MainNavScreen()),
    );
  }
}
