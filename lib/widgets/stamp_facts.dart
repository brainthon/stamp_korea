import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StampFacts extends StatelessWidget {
  const StampFacts({super.key, required this.fields});
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) => Column(
    children:
        fields.entries
            .map(
              (entry) => Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.borderGray),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value.trim().isEmpty ? '자료 없음' : entry.value,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
  );
}

class StampDetailImage extends StatelessWidget {
  const StampDetailImage({super.key, required this.url, required this.label});
  final String url, label;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.subtleGray,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300, maxWidth: 440),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          semanticLabel: label,
          errorBuilder:
              (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Icon(Icons.image_not_supported_outlined, size: 48),
              ),
        ),
      ),
    ),
  );
}
