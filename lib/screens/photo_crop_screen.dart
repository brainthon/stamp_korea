import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../services/photo_quality.dart';

class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  RangeValues horizontal = const RangeValues(0, 1);
  RangeValues vertical = const RangeValues(0, 1);
  bool saving = false;
  late final double ratio;
  @override
  void initState() {
    super.initState();
    final image = img.decodeImage(widget.bytes)!;
    ratio = image.width / image.height;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('우표 영역 자르기')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('우표의 네 모서리와 천공이 모두 남도록 범위를 맞춰 주세요. 여러 장이라면 한 장만 선택해 주세요.'),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: Center(
              child: AspectRatio(
                aspectRatio: ratio,
                child: LayoutBuilder(
                  builder:
                      (context, size) => Stack(
                        children: [
                          Positioned.fill(
                            child: Image.memory(widget.bytes, fit: BoxFit.fill),
                          ),
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: .35),
                            ),
                          ),
                          Positioned(
                            left: size.maxWidth * horizontal.start,
                            top: size.maxHeight * vertical.start,
                            width:
                                size.maxWidth *
                                (horizontal.end - horizontal.start),
                            height:
                                size.maxHeight *
                                (vertical.end - vertical.start),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('좌우 범위'),
          RangeSlider(
            values: horizontal,
            onChanged:
                saving
                    ? null
                    : (v) {
                      if (v.end - v.start >= .1) setState(() => horizontal = v);
                    },
          ),
          const Text('위아래 범위'),
          RangeSlider(
            values: vertical,
            onChanged:
                saving
                    ? null
                    : (v) {
                      if (v.end - v.start >= .1) setState(() => vertical = v);
                    },
          ),
          FilledButton(
            onPressed:
                saving
                    ? null
                    : () async {
                      setState(() => saving = true);
                      try {
                        final result = await compute(
                          cropStampPhoto,
                          <String, Object>{
                            'bytes': widget.bytes,
                            'bounds': <double>[
                              horizontal.start,
                              vertical.start,
                              horizontal.end,
                              vertical.end,
                            ],
                          },
                        );
                        if (context.mounted) Navigator.pop(context, result);
                      } catch (_) {
                        if (context.mounted) {
                          setState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('자르지 못했어요. 다시 시도해 주세요.'),
                            ),
                          );
                        }
                      }
                    },
            child: Text(saving ? '처리 중…' : '선택 영역 적용'),
          ),
        ],
      ),
    ),
  );
}
