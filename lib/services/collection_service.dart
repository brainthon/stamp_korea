import 'wishlist_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stamp.dart';
import 'stamp_repository.dart';
import 'supabase_service.dart';

class CollectionService {
  static List<CollectionItem> _items = [];
  static Set<String> _wishlistIds = {};
  static final Set<String> _wishlistBusy = {};
  static bool _initialized = false;
  static String? _owner;
  static int _generation = 0;
  static bool loading = false;
  static String? syncError;
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);
  static String get _collectionKey =>
      _owner == null
          ? 'user_stamp_collection_v1'
          : 'user_stamp_collection_v2_$_owner';
  static String get _wishlistKey =>
      _owner == null
          ? 'user_stamp_wishlist_v1'
          : 'user_stamp_wishlist_v2_$_owner';

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await StampRepository.initialize();
    await SupabaseService.initialize();
    SupabaseService.authStateChanges?.listen(
      (state) {
        if (state.session?.user.id != _owner) {
          reloadForAccount();
        }
      },
      onError: (_) {
        syncError = '로그인 연결을 확인하고 다시 시도해 주세요.';
        notifier.value++;
      },
    );
    await reloadForAccount();
  }

  static Future<void> reloadForAccount() async {
    final generation = ++_generation;
    _owner = SupabaseService.currentUser?.id;
    _items = [];
    _wishlistIds = {};
    _wishlistBusy.clear();
    syncError = null;
    loading = true;
    notifier.value++;
    final key = _collectionKey, wishKey = _wishlistKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _generation) return;
      _wishlistIds = (prefs.getStringList(wishKey) ?? []).toSet();
      if (_owner != null) {
        final owner = _owner!;
        await WishlistService.importLocal(owner, _wishlistIds);
        if (generation != _generation) return;
        _wishlistIds = await WishlistService.fetch(owner);
        if (generation != _generation) return;
        // Remove the legacy local copy after successful migration. Cloud is authoritative.
        await prefs.remove(wishKey);
        if (generation != _generation) return;
        final remote = await SupabaseService.fetchCollections();
        if (generation != _generation) return;
        _items = remote ?? []; // An empty cloud collection is authoritative.
      } else {
        _items =
            (prefs.getStringList(key) ?? [])
                .map((raw) {
                  try {
                    return CollectionItem.fromJson(raw);
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<CollectionItem>()
                .toList();
      }
    } catch (_) {
      if (generation == _generation) {
        syncError = '수집 기록을 불러오지 못했어요. 연결을 확인하고 다시 시도해 주세요.';
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        notifier.value++;
      }
    }
  }

  static void _check(int generation) {
    if (generation != _generation ||
        _owner != SupabaseService.currentUser?.id) {
      throw StateError('계정이 변경되었습니다. 다시 시도해 주세요.');
    }
    if (loading || syncError != null) {
      throw StateError('수집 기록을 먼저 새로고침해 주세요.');
    }
  }

  static List<CollectionItem> getItems() => List.unmodifiable(_items);
  static bool isCollected(String stampId) =>
      _items.any((i) => i.stampId == stampId);
  static List<CollectionItem> getItemsByStampId(String stampId) =>
      _items.where((item) => item.stampId == stampId).toList();
  static int countByStampId(String stampId) =>
      getItemsByStampId(stampId).fold(0, (total, item) => total + item.count);

  static CollectionItem? getItemByStampId(String stampId) {
    for (final item in _items) {
      if (item.stampId == stampId) return item;
    }
    return null;
  }

  static Future<void> addOrUpdateItem(
    CollectionItem item, {
    Stamp? stamp,
    Uint8List? photoBytes,
  }) async {
    final generation = _generation;
    _check(generation);
    // AI observations never become an official catalogue entry automatically.
    var map = item.toMap();
    if (photoBytes != null && photoBytes.isNotEmpty) {
      if (_owner != null) {
        final path = await SupabaseService.uploadStampPhoto(
          photoBytes,
          item.stampId,
        );
        _check(generation);
        map['user_image_path'] = path;
        map['user_image_url'] = await SupabaseService.photoUrl(path);
      } else {
        map['user_image_url'] =
            'data:image/jpeg;base64,${base64Encode(photoBytes)}';
      }
    }
    _check(generation);
    final saved = CollectionItem.fromMap(map);
    if (_owner != null) await SupabaseService.saveCollection(saved);
    _check(generation);
    final index = _items.indexWhere((i) => i.id == saved.id);
    if (index >= 0) {
      _items[index] = saved;
    } else {
      _items.add(saved);
    }
    await _saveItems();
    notifier.value++;
  }

  static Future<void> removeItem(String id) async {
    final generation = _generation;
    _check(generation);
    if (_owner != null) await SupabaseService.deleteCollection(id);
    _check(generation);
    _items.removeWhere((i) => i.id == id);
    await _saveItems();
    notifier.value++;
  }

  static Future<void> _saveItems() async {
    // Cloud records stay in Supabase; do not cache personal photos on logout.
    if (_owner != null) return;
    final key = _collectionKey, values = _items.map((i) => i.toJson()).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, values);
  }

  static int get wishlistCount => _wishlistIds.length;

  static bool isWishlisted(String id) => _wishlistIds.contains(id);
  static Future<void> toggleWishlist(String id) async {
    final generation = _generation;
    _check(generation);
    if (_wishlistBusy.contains(id)) return;
    _wishlistBusy.add(id);
    final wanted = !_wishlistIds.contains(id);
    try {
      if (_owner != null) {
        await WishlistService.set(_owner!, id, wanted);
        _check(generation);
      }
      if (wanted) {
        _wishlistIds.add(id);
      } else {
        _wishlistIds.remove(id);
      }
      if (_owner == null) {
        final key = _wishlistKey, values = _wishlistIds.toList();
        final prefs = await SharedPreferences.getInstance();
        _check(generation);
        await prefs.setStringList(key, values);
      }
      notifier.value++;
    } finally {
      if (generation == _generation) _wishlistBusy.remove(id);
    }
  }

  // Statistics
  static Map<String, dynamic> getStatistics() {
    final totalDatabaseCount = StampRepository.getAllStamps().length;
    final collectedUniqueCount = _items.map((i) => i.stampId).toSet().length;
    final totalPieces = _items.fold<int>(0, (sum, i) => sum + i.count);
    final overallPercentage =
        totalDatabaseCount > 0
            ? (collectedUniqueCount / totalDatabaseCount) * 100
            : 0.0;

    // Condition breakdown
    final conditionMap = <StampCondition, int>{};
    for (final cond in StampCondition.values) {
      conditionMap[cond] = _items.where((i) => i.condition == cond).length;
    }

    // Era completion breakdown
    final eraMap = <String, int>{};
    for (final stamp in StampRepository.getAllStamps()) {
      if (isCollected(stamp.id)) {
        eraMap[stamp.eraName] = (eraMap[stamp.eraName] ?? 0) + 1;
      }
    }

    return {
      'totalDbCount': totalDatabaseCount,
      'uniqueCollected': collectedUniqueCount,
      'totalPieces': totalPieces,
      'wishlistCount': _wishlistIds.length,
      'completionRate': overallPercentage,
      'conditions': conditionMap,
      'eraCollected': eraMap,
    };
  }

  // Exportable Text Report
  static String generateCatalogTextReport() {
    final stats = getStatistics();
    final buffer = StringBuffer();

    buffer.writeln('==============================================');
    buffer.writeln(' 📜 대한민국 우표 수집 도감 (StampKorea Catalog)');
    buffer.writeln('==============================================');
    buffer.writeln(
      '• 총 보유 우표: ${stats['uniqueCollected']}종 (${stats['totalPieces']}장)',
    );
    buffer.writeln(
      '• 도감 달성률: ${(stats['completionRate'] as double).toStringAsFixed(1)}%',
    );
    buffer.writeln('• 출력 일시: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('----------------------------------------------\n');

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final stamp = StampRepository.getStampById(item.stampId);
      if (stamp == null) continue;

      buffer.writeln('[${i + 1}] ${stamp.name}');
      buffer.writeln('  - 발행: ${stamp.issueYear}년 (${stamp.issueDate})');
      buffer.writeln(
        '  - 액면가: ${stamp.faceValue} | 발행량: ${stamp.formattedVolume}',
      );
      buffer.writeln('  - 소장상태: ${item.condition.title} (보유: ${item.count}장)');
      if (item.storageLocation != null && item.storageLocation!.isNotEmpty) {
        buffer.writeln('  - 보관위치: ${item.storageLocation}');
      }
      if (item.userImageUrl != null && item.userImageUrl!.isNotEmpty) {
        buffer.writeln('  - 사진: ${item.userImageUrl}');
      }
      if (item.memo != null && item.memo!.isNotEmpty) {
        buffer.writeln('  - 수집메모: ${item.memo}');
      }

      buffer.writeln('');
    }

    buffer.writeln('==============================================');
    buffer.writeln('우표모아 - 나의 우표 수집 기록');
    return buffer.toString();
  }
}
