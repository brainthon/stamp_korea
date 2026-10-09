import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.child, this.initialization});
  final Widget child;
  final Future<void>? initialization;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool ready = false;
  bool started = false;
  bool showBrandIntro = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    _start(MediaQuery.disableAnimationsOf(context));
  }

  Future<void> _start(bool reduced) async {
    // The OS launch screen stays static. Branding is a one-time app intro,
    // never an artificial delay on every cold start or OAuth return.
    const seenKey = 'brand_intro_seen_v1';
    SharedPreferences? preferences;
    var firstLaunch = false;
    try {
      preferences = await SharedPreferences.getInstance();
      firstLaunch = !(preferences.getBool(seenKey) ?? false);
    } catch (_) {
      // Storage failure must not delay entry to the app.
    }
    if (!mounted) return;
    showBrandIntro = firstLaunch && !reduced;
    setState(() {});
    if (showBrandIntro) entrance.forward();
    await Future.wait<void>([
      (widget.initialization ?? Future<void>.value()).catchError((Object _) {}),
      if (showBrandIntro) Future<void>.delayed(entrance.duration!),
    ]);
    if (!mounted) return;
    if (firstLaunch) {
      try {
        await preferences?.setBool(seenKey, true);
      } catch (_) {
        // Preferences are optional; app initialization has already completed.
      }
    }
    if (mounted) setState(() => ready = true);
  }

  Widget _stampCard(int index) {
    final progress = Interval(
      index * .14,
      .34 + index * .14,
      curve: Curves.easeOutCubic,
    ).transform(entrance.value);
    const positions = [
      Offset(8, 80),
      Offset(60, 44),
      Offset(114, 12),
      Offset(158, 68),
    ];
    const angles = [-.23, -.12, .09, .22];
    final position = positions[index];
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 45 * (1 - progress)),
          child: Transform.rotate(
            angle: angles[index] - .08 * (1 - progress),
            child: Transform.scale(
              scale: .9 + .1 * progress,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: const Size(122, 146),
                  painter: _StampIllustration(index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration:
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
    child:
        ready
            ? widget.child
            : Scaffold(
              key: const ValueKey('yellow-splash'),
              backgroundColor: AppTheme.brandYellow,
              body: SafeArea(
                child:
                    !showBrandIntro
                        ? const SizedBox.expand()
                        : Center(
                          child: Semantics(
                            label: '우표모아 시작 중',
                            child: ExcludeSemantics(
                              child: AnimatedBuilder(
                                animation: entrance,
                                builder: (context, _) {
                                  final logo = const Interval(
                                    .65,
                                    .94,
                                    curve: Curves.easeOutCubic,
                                  ).transform(entrance.value);
                                  final caption = const Interval(
                                    .82,
                                    1,
                                    curve: Curves.easeOut,
                                  ).transform(entrance.value);
                                  return Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 290,
                                          height: 250,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              for (var i = 0; i < 4; i++)
                                                _stampCard(i),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        Opacity(
                                          opacity: logo,
                                          child: Transform.translate(
                                            offset: Offset(0, 12 * (1 - logo)),
                                            child: const Text(
                                              '우표모아',
                                              style: TextStyle(
                                                color: AppTheme.brandInk,
                                                fontSize: 40,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -1,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Opacity(
                                          opacity: caption,
                                          child: const Text(
                                            '좋아하는 우표를, 하나씩',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: AppTheme.brandInk,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
              ),
            ),
  );
}

/// Lightweight vector artwork: no network image or decoding on app launch.
class _StampIllustration extends CustomPainter {
  const _StampIllustration(this.era);
  final int era;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 154, size.height / 184);
    final paper = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 4, 146, 176),
      const Radius.circular(4),
    );
    canvas.drawShadow(
      Path()..addRRect(paper),
      const Color(0xFF8A5B16),
      7,
      false,
    );
    var outline = Path()..addRRect(paper);
    final holes = Path();
    for (double x = 13; x < 150; x += 16) {
      holes.addOval(Rect.fromCircle(center: Offset(x, 4), radius: 4));
      holes.addOval(Rect.fromCircle(center: Offset(x, 180), radius: 4));
    }
    for (double y = 13; y < 180; y += 16) {
      holes.addOval(Rect.fromCircle(center: Offset(4, y), radius: 4));
      holes.addOval(Rect.fromCircle(center: Offset(150, y), radius: 4));
    }
    outline = Path.combine(PathOperation.difference, outline, holes);
    canvas.drawPath(outline, Paint()..color = const Color(0xFFFFFCED));
    const backgrounds = [
      Color(0xFFB9664B),
      Color(0xFF64877B),
      Color(0xFF8CBBD0),
      Color(0xFFF9DF85),
    ];
    canvas.drawRect(
      const Rect.fromLTWH(17, 18, 120, 148),
      Paint()..color = backgrounds[era],
    );
    if (era == 3) {
      canvas.drawCircle(
        const Offset(77, 82),
        44,
        Paint()..color = const Color(0xFFFFF3C2),
      );
      final petal = Paint()..color = const Color(0xFFEBA33A);
      canvas.save();
      canvas.translate(77, 77);
      for (var i = 0; i < 8; i++) {
        canvas.save();
        canvas.rotate(i * math.pi / 4);
        canvas.drawOval(const Rect.fromLTWH(-9, -32, 18, 28), petal);
        canvas.restore();
      }
      canvas.drawCircle(Offset.zero, 12, Paint()..color = AppTheme.brandInk);
      canvas.restore();
      final stem =
          Paint()
            ..color = const Color(0xFF62734B)
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke;
      canvas.drawPath(
        Path()
          ..moveTo(77, 89)
          ..quadraticBezierTo(73, 111, 82, 133),
        stem,
      );
      canvas.drawOval(
        const Rect.fromLTWH(80, 106, 20, 10),
        Paint()..color = const Color(0xFF62734B),
      );
    } else if (era == 0) {
      // Early postal emblem, rendered as an illustrative seal.
      final ornament = Paint()..color = const Color(0xFFFFE9C5);
      canvas.drawOval(const Rect.fromLTWH(32, 43, 90, 92), ornament);
      canvas.drawOval(
        const Rect.fromLTWH(38, 49, 78, 80),
        Paint()..color = backgrounds[0],
      );
      canvas.drawCircle(const Offset(77, 88), 25, ornament);
      canvas.drawArc(
        const Rect.fromLTWH(52, 63, 50, 50),
        0,
        math.pi,
        true,
        Paint()..color = const Color(0xFF554D53),
      );
      canvas.drawCircle(const Offset(65, 88), 12.5, ornament);
      canvas.drawCircle(
        const Offset(89, 88),
        12.5,
        Paint()..color = const Color(0xFF554D53),
      );
      for (var i = 0; i < 5; i++) {
        canvas.drawLine(
          Offset(27, 51.0 + i * 19),
          Offset(30, 51.0 + i * 19),
          ornament..strokeWidth = 2,
        );
        canvas.drawLine(
          Offset(124, 51.0 + i * 19),
          Offset(127, 51.0 + i * 19),
          ornament,
        );
      }
    } else if (era == 1) {
      // Mid-century architecture, with a restrained engraved palette.
      final stone = Paint()..color = const Color(0xFFFFEAC9);
      canvas.drawCircle(
        const Offset(101, 56),
        15,
        Paint()..color = const Color(0xFFADC0A0),
      );
      for (var tier = 0; tier < 3; tier++) {
        final y = 117.0 - tier * 25;
        final width = 68.0 - tier * 14;
        canvas.drawRect(
          Rect.fromLTWH(77 - width / 2 + 8, y - 15, width - 16, 19),
          stone,
        );
        canvas.drawPath(
          Path()
            ..moveTo(77 - width / 2 - 7, y - 15)
            ..lineTo(77, y - 31)
            ..lineTo(77 + width / 2 + 7, y - 15)
            ..close(),
          stone,
        );
      }
      canvas.drawRect(const Rect.fromLTWH(36, 126, 82, 7), stone);
    } else {
      // Contemporary nature stamp: mountain silhouettes and a flying bird.
      canvas.drawCircle(
        const Offset(106, 57),
        18,
        Paint()..color = const Color(0xFFFFE8AE),
      );
      canvas.drawPath(
        Path()
          ..moveTo(17, 137)
          ..lineTo(55, 87)
          ..lineTo(93, 137)
          ..close(),
        Paint()..color = const Color(0xFF668F94),
      );
      canvas.drawPath(
        Path()
          ..moveTo(65, 137)
          ..lineTo(106, 101)
          ..lineTo(137, 137)
          ..close(),
        Paint()..color = const Color(0xFF427478),
      );
      canvas.drawPath(
        Path()
          ..moveTo(37, 67)
          ..quadraticBezierTo(61, 51, 76, 73)
          ..quadraticBezierTo(98, 62, 115, 78)
          ..quadraticBezierTo(88, 77, 74, 85)
          ..quadraticBezierTo(53, 70, 37, 67)
          ..close(),
        Paint()..color = const Color(0xFFFFFCED),
      );
    }
    final text = TextPainter(textDirection: TextDirection.ltr);
    void label(String value, Offset offset, double fontSize) {
      text.text = TextSpan(
        text: value,
        style: TextStyle(
          color: era == 3 ? AppTheme.brandInk : const Color(0xFFFFFCED),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      );
      text.layout();
      text.paint(canvas, offset);
    }

    label(era == 0 ? '朝鮮郵便' : 'KOREA', const Offset(27, 27), 9);
    label(['5 MUN', '10', '80', '500'][era], const Offset(26, 144), 13);
    label('POST', const Offset(104, 148), 8);
  }

  @override
  bool shouldRepaint(covariant _StampIllustration oldDelegate) =>
      oldDelegate.era != era;
}
