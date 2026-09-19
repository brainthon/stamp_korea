import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/stamp.dart';

class StampVisualView extends StatelessWidget {
  final Stamp stamp;
  final double width;
  final double height;
  final bool showPerforations;
  final bool showPostmark;
  final Uint8List? userImageBytes; // 사용자가 촬영/선택한 실물 사진 바이트
  final String? overrideImageUrl; // 수파베이스/웹 이미지 URL

  const StampVisualView({
    super.key,
    required this.stamp,
    this.width = 160,
    this.height = 210,
    this.showPerforations = true,
    this.showPostmark = false,
    this.userImageBytes,
    this.overrideImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (stamp.id.startsWith('epost_') && userImageBytes == null) {
      return SizedBox(
        width: width,
        height: height,
        child: Image.network(
          overrideImageUrl ?? stamp.imageUrl ?? '',
          fit: BoxFit.contain,
          semanticLabel: '${stamp.name} 공식 우표 이미지',
          errorBuilder:
              (_, __, ___) =>
                  const Center(child: Icon(Icons.image_not_supported_outlined)),
        ),
      );
    }
    final primaryColor = _parseColor(stamp.primaryColors.first);
    final secondaryColor =
        stamp.primaryColors.length > 1
            ? _parseColor(stamp.primaryColors[1])
            : Colors.white;

    Widget stampContent = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F0),
        borderRadius: BorderRadius.circular(showPerforations ? 0 : 6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(1, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 1. 내부 액자 프레임
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.75),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor.withValues(alpha: 0.08),
                      secondaryColor.withValues(alpha: 0.04),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    // 상단 헤더 (국호 & 연도)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _getHeaderTitle(stamp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: width * 0.05,
                                fontWeight: FontWeight.w900,
                                color: primaryColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${stamp.issueYear}년',
                            style: TextStyle(
                              fontSize: width * 0.045,
                              fontWeight: FontWeight.w700,
                              color: primaryColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 중앙 도안: 실제 촬영 사진 OR 웹 이미지 OR 벡터 그래픽
                    Expanded(
                      child: Center(
                        child: _buildArtworkContent(
                          context,
                          primaryColor,
                          width,
                        ),
                      ),
                    ),

                    // 하단 푸터 (액면가 & 국호 한글 표기)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        border: Border(
                          top: BorderSide(
                            color: primaryColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              stamp.faceValue,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: width * 0.055,
                                fontWeight: FontWeight.w900,
                                color: primaryColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '대한민국',
                            style: TextStyle(
                              fontSize: width * 0.04,
                              fontWeight: FontWeight.bold,
                              color: primaryColor.withValues(alpha: 0.85),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. 우편 소인(Postmark) 오버레이 (한글 표기)
          if (showPostmark)
            Positioned(
              right: 6,
              top: 10,
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  width: width * 0.55,
                  height: width * 0.55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '서울우체국',
                        style: TextStyle(
                          fontSize: width * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                      Text(
                        stamp.issueDate,
                        style: TextStyle(
                          fontSize: width * 0.035,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                      Text(
                        '우 편',
                        style: TextStyle(
                          fontSize: width * 0.045,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (!showPerforations) {
      return stampContent;
    }

    return CustomPaint(
      foregroundPainter: StampPerforationPainter(
        perforationRadius: 3.0,
        spacing: 8.5,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: stampContent,
    );
  }

  Widget _buildArtworkContent(BuildContext context, Color primary, double w) {
    // 1순위: 사용자가 직접 촬영/선택한 사진 바이트
    if (userImageBytes != null && userImageBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          userImageBytes!,
          width: w * 0.82,
          height: w * 0.82,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => _buildFallbackGraphic(primary, w),
        ),
      );
    }

    // 2순위: Supabase Storage 또는 로컬 base64 Data URI 또는 웹 URL
    final url = overrideImageUrl ?? stamp.imageUrl;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('data:image')) {
        try {
          final base64Str = url.contains(',') ? url.split(',').last : url;
          final bytes = base64Decode(base64Str);
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              bytes,
              width: w * 0.82,
              height: w * 0.82,
              fit: BoxFit.cover,
              errorBuilder:
                  (ctx, err, stack) => _buildFallbackGraphic(primary, w),
            ),
          );
        } catch (_) {
          return _buildFallbackGraphic(primary, w);
        }
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          url,
          width: w * 0.82,
          height: w * 0.82,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (ctx, err, stack) => _buildFallbackGraphic(primary, w),
        ),
      );
    }

    // 3순위: 전통 문양 및 엠블럼 일러스트 그래픽
    return _buildFallbackGraphic(primary, w);
  }

  Widget _buildFallbackGraphic(Color primary, double w) {
    IconData iconData = Icons.local_post_office;
    String symbolText = '';

    switch (stamp.illustrationSvgPlaceholder) {
      case 'vintage_crest':
      case 'vintage_crest_blue':
        iconData = Icons.account_balance;
        symbolText = '우정총국';
        break;
      case 'taegeuk_classic':
        iconData = Icons.blur_circular;
        symbolText = '태극';
        break;
      case 'plum_blossom':
        iconData = Icons.filter_vintage;
        symbolText = '이화';
        break;
      case 'royal_crown':
        iconData = Icons.military_tech;
        symbolText = '칭경예식';
        break;
      case 'liberation_sun':
        iconData = Icons.wb_sunny;
        symbolText = '광복1주년';
        break;
      case 'korea_flag_crest':
        iconData = Icons.flag;
        symbolText = '정부수립';
        break;
      case 'dokdo_island':
        iconData = Icons.landscape;
        symbolText = '독도';
        break;
      case 'expressway_bridge':
        iconData = Icons.add_road;
        symbolText = '경부고속';
        break;
      case 'mountain_everest':
        iconData = Icons.terrain;
        symbolText = '에베레스트';
        break;
      case 'hodori_mascot':
        iconData = Icons.emoji_events;
        symbolText = '호돌이';
        break;
      case 'torch_flame':
        iconData = Icons.local_fire_department;
        symbolText = '성화봉송';
        break;
      case 'kkumdori_star':
        iconData = Icons.auto_awesome;
        symbolText = '꿈돌이';
        break;
      case 'hangeul_scroll':
        iconData = Icons.menu_book;
        symbolText = '훈민정음';
        break;
      case 'worldcup_ball':
        iconData = Icons.sports_soccer;
        symbolText = '월드컵';
        break;
      case 'pororo_character':
        iconData = Icons.mood;
        symbolText = '뽀로로';
        break;
      case 'pyeongchang_tiger':
        iconData = Icons.ac_unit;
        symbolText = '수호랑';
        break;
      case 'space_rocket':
        iconData = Icons.rocket_launch;
        symbolText = '누리호';
        break;
      case 'korean_mask':
        iconData = Icons.theater_comedy;
        symbolText = '탈춤';
        break;
      default:
        iconData = Icons.local_post_office;
        symbolText = stamp.category;
    }

    return Container(
      width: w * 0.68,
      height: w * 0.68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary.withValues(alpha: 0.12),
        border: Border.all(color: primary.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, size: w * 0.26, color: primary),
          const SizedBox(height: 2),
          Text(
            symbolText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: w * 0.05,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }

  String _getHeaderTitle(Stamp s) {
    if (s.issueYear <= 1895) return '대조선';
    if (s.issueYear <= 1910) return '대한제국';
    return '대한민국';
  }

  Color _parseColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF142850);
    }
  }
}

class StampPerforationPainter extends CustomPainter {
  final double perforationRadius;
  final double spacing;
  final Color backgroundColor;

  StampPerforationPainter({
    required this.perforationRadius,
    required this.spacing,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.fill;

    final horizontalSteps = (size.width / spacing).floor();
    final hOffset = (size.width - (horizontalSteps * spacing)) / 2;

    for (int i = 0; i <= horizontalSteps; i++) {
      final cx = hOffset + (i * spacing);
      canvas.drawCircle(Offset(cx, 0), perforationRadius, paint);
      canvas.drawCircle(Offset(cx, size.height), perforationRadius, paint);
    }

    final verticalSteps = (size.height / spacing).floor();
    final vOffset = (size.height - (verticalSteps * spacing)) / 2;

    for (int i = 0; i <= verticalSteps; i++) {
      final cy = vOffset + (i * spacing);
      canvas.drawCircle(Offset(0, cy), perforationRadius, paint);
      canvas.drawCircle(Offset(size.width, cy), perforationRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
