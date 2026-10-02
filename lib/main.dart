import 'screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/supabase_service.dart';
import 'services/collection_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_nav_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 상태바 스타일 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const StampKoreaApp());
}

class StampKoreaApp extends StatefulWidget {
  const StampKoreaApp({super.key});

  @override
  State<StampKoreaApp> createState() => _StampKoreaAppState();
}

class _StampKoreaAppState extends State<StampKoreaApp> {
  late final Future<void> initialization = _initialize();

  Future<void> _initialize() async {
    await SupabaseService.initialize();
    await CollectionService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '우표모아 (StampKorea)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.light,
      home: SplashScreen(
        initialization: initialization,
        child:
            Uri.base.queryParameters['admin'] == 'true'
                ? const AdminScreen()
                : const MainNavScreen(),
      ),
    );
  }
}
