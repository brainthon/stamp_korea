import 'dart:convert';
import 'dart:io';
import 'package:stamp_korea/models/stamp_theme.dart';

void main() {
  final file = File('assets/catalog/official_stamps.json');
  final rows = jsonDecode(file.readAsStringSync()) as List;
  final counts = <String, int>{};
  for (final row in rows) {
    final theme = StampTheme.classify(
      name: row['name'] ?? '',
      design: row['design'] ?? '',
      description: row['description'] ?? '',
    );
    row['theme'] = theme;
    row['theme_method'] = 'keyword_v1';
    counts[theme] = (counts[theme] ?? 0) + 1;
  }
  file.writeAsStringSync(jsonEncode(rows));
  stdout.writeln(jsonEncode(counts));
}
