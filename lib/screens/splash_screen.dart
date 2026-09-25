import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.child,
    this.initialization,
  });
  final Widget child;
  final Future<void>? initialization;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    Future.wait<void>([
      widget.initialization ?? Future<void>.value(),
      Future<void>.delayed(const Duration(milliseconds: 1200)),
    ]).then<void>(
      (_) => _showApp(),
      onError: (Object _, StackTrace __) => _showApp(),
    );
  }

  void _showApp() {
    if (mounted) setState(() => ready = true);
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration:
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 350),
    child:
        ready
            ? widget.child
            : Scaffold(
              key: const ValueKey('splash'),
              backgroundColor: AppTheme.canvas,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'assets/branding/app-logo.png',
                        width: 128,
                        height: 128,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '우표모아',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '좋아하는 우표를, 하나씩',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
  );
}
