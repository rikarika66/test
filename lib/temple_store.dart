import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// 寺院1件分のデータ
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
    required this.goshuinImagePaths, // 最大2枚
    required this.updatedAtMillis,
  });

  final String id;
  String templeName;
  String visitDateText;
  String address;
  String sect;
  String honzon;
  String memo;

  /// 📷 アルバム画像（ファイルパス）
  List<String> albumImagePaths;

  /// 🖼 御朱印画像（ファイルパス・最大2枚）
  List<String> goshuinImagePaths;

  int updatedAtMillis;

  // ----------------------------
  // JSON 保存
  // ----------------------------
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

  // ----------------------------
  // JSON 復元
  // ----------------------------
  static TempleEntry fromJson(Map<String, dynamic> json) {
    final albumPaths = (json['albumImagePaths'] as List<dynamic>? ?? [])
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toList();

    final goshuinPaths = (json['goshuinImagePaths'] as List<dynamic>? ?? [])
        .whereType<String>()
        .where((p) => p.isNotEmpty)
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

  /// ファイルが実在するか（UIで安全に使う用）
  static bool exists(String path) {
    return path.isNotEmpty && File(path).existsSync();
  }
}

// ===================================================
// 永続化ストア
// ===================================================
class TempleStore {
  static const String _listKey = 'templeEntries_v2';

  static Future<List<TempleEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_listKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final list = decoded
          .map((e) => TempleEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      list.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<bool> saveAll(List<TempleEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(entries.map((e) => e.toJson()).toList());

    try {
      return await prefs.setString(_listKey, payload);
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

    return saveAll(all);
  }

  static Future<void> deleteById(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await saveAll(all);
  }

  /// 新規作成（ID自動生成）
  static TempleEntry newEntry() {
    return newEntryWithId(DateTime.now().millisecondsSinceEpoch.toString());
  }

  /// ★新規作成（ID指定）
  static TempleEntry newEntryWithId(String id) {
    final now = DateTime.now();
    final dateText = '${now.year}年${now.month}月${now.day}日';

    return TempleEntry(
      id: id,
      templeName: '',
      visitDateText: dateText,
      address: '',
      sect: '',
      honzon: '',
      memo: '',
      albumImagePaths: [],
      goshuinImagePaths: [],
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
