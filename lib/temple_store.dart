import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'image_storage.dart';

/// 寺院1件分のデータ（★画像はパスで保持）
class TempleEntry {
  TempleEntry({
    required this.id,
    required this.templeName,
    required this.visitDateText,
    required this.address,
    required this.sect,
    required this.honzon,
    required this.memo,
    required this.albumImagePaths,
    required this.goshuinImagePaths, // ★最大2枚
    required this.updatedAtMillis,
  });

  final String id;
  String templeName;
  String visitDateText; // 例: 2025年11月28日
  String address;
  String sect;
  String honzon;
  String memo;

  /// 📷 アルバム画像（ファイルパス）
  List<String> albumImagePaths;

  /// 🖼 御朱印画像（ファイルパス・最大2枚）
  List<String> goshuinImagePaths;

  int updatedAtMillis;

  Map<String, dynamic> toJson() => {
        'id': id,
        'templeName': templeName,
        'visitDateText': visitDateText,
        'address': address,
        'sect': sect,
        'honzon': honzon,
        'memo': memo,
        'albumImagePaths': albumImagePaths,
        'goshuinImagePaths': goshuinImagePaths,
        'updatedAtMillis': updatedAtMillis,
      };

  static TempleEntry fromJson(Map<String, dynamic> json) {
    final albumPaths = (json['albumImagePaths'] as List<dynamic>? ?? [])
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty)
        .toList();

    final goshuinPaths = (json['goshuinImagePaths'] as List<dynamic>? ?? [])
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty)
        .take(2)
        .toList();

    return TempleEntry(
      id: (json['id'] as String?) ?? _genId(),
      templeName: (json['templeName'] as String?) ?? '',
      visitDateText: (json['visitDateText'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      sect: (json['sect'] as String?) ?? '',
      honzon: (json['honzon'] as String?) ?? '',
      memo: (json['memo'] as String?) ?? '',
      albumImagePaths: albumPaths,
      goshuinImagePaths: goshuinPaths,
      updatedAtMillis: (json['updatedAtMillis'] as int?) ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  static String _genId() => DateTime.now().millisecondsSinceEpoch.toString();
}

class TempleStore {
  static const String _listKey = 'templeEntries_v1';

  static Future<List<TempleEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_listKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final list = decoded
          .whereType<dynamic>()
          .map((e) => TempleEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      // 新しい順
      list.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<bool> saveAll(List<TempleEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = entries.map((e) => e.toJson()).toList();
    final payload = jsonEncode(jsonList);

    try {
      final ok = await prefs.setString(_listKey, payload);
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<TempleEntry?> loadById(String id) async {
    final all = await loadAll();
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> upsert(TempleEntry entry) async {
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.id == entry.id);

    entry.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;

    if (idx >= 0) {
      all[idx] = entry;
    } else {
      all.insert(0, entry);
    }

    return await saveAll(all);
  }

  /// ★寺院データ削除（画像ファイルも一緒に削除）
  static Future<void> deleteById(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await saveAll(all);

    // 画像フォルダごと削除（失敗しても落ちない設計）
    await ImageStorage.deleteEntryDir(id);
  }

  /// 新規作成（ID自動生成）
  static TempleEntry newEntry() => newEntryWithId(_genId());

  /// ★新規作成（ID指定）
  /// BookPage が templeId を持って開かれるケースでも、IDがブレないようにする
  static TempleEntry newEntryWithId(String id) {
    final now = DateTime.now();
    final dateText = '${now.year}年${now.month}月${now.day}日';
    return TempleEntry(
      id: id,
      templeName: '',
      visitDateText: dateText, // 初期値＝今日（現状維持）
      address: '',
      sect: '',
      honzon: '',
      memo: '',
      albumImagePaths: const [],
      goshuinImagePaths: const [],
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static String _genId() => DateTime.now().millisecondsSinceEpoch.toString();
}
