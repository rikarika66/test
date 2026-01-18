import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class TempleEntry {
  TempleEntry({
    required this.id,
    required this.templeName,
    required this.visitDateText,
    required this.address,
    required this.sect,
    required this.honzon,
    required this.memo,
    required this.albumImages,
    required this.goshuinImages, // ★御朱印（最大2枚）
    required this.updatedAtMillis,
  });

  final String id;
  String templeName;
  String visitDateText; // 例: 2025年11月28日
  String address;
  String sect;
  String honzon;
  String memo;

  /// アルバム
  List<Uint8List> albumImages;

  /// ★御朱印（最大2枚運用）
  List<Uint8List> goshuinImages;

  int updatedAtMillis;

  Map<String, dynamic> toJson() => {
        'id': id,
        'templeName': templeName,
        'visitDateText': visitDateText,
        'address': address,
        'sect': sect,
        'honzon': honzon,
        'memo': memo,
        'albumImages': albumImages.map((e) => base64Encode(e)).toList(),
        'goshuinImages': goshuinImages.map((e) => base64Encode(e)).toList(),
        'updatedAtMillis': updatedAtMillis,
      };

  static TempleEntry fromJson(Map<String, dynamic> json) {
    final album = (json['albumImages'] as List<dynamic>? ?? [])
        .whereType<String>()
        .map((s) {
          try {
            return base64Decode(s);
          } catch (_) {
            return Uint8List(0);
          }
        })
        .where((b) => b.isNotEmpty)
        .toList();

    // ★新形式：goshuinImages
    final gList = (json['goshuinImages'] as List<dynamic>? ?? [])
        .whereType<String>()
        .map((s) {
          try {
            return base64Decode(s);
          } catch (_) {
            return Uint8List(0);
          }
        })
        .where((b) => b.isNotEmpty)
        .toList();

    // ★旧形式：goshuinImage（単体）にも後方互換で対応
    final old = json['goshuinImage'];
    if (gList.isEmpty && old is String && old.isNotEmpty) {
      try {
        gList.add(base64Decode(old));
      } catch (_) {}
    }

    // ★運用：最大2枚に制限
    final normalized = gList.take(2).toList();

    return TempleEntry(
      id: (json['id'] as String?) ?? _genId(),
      templeName: (json['templeName'] as String?) ?? '',
      visitDateText: (json['visitDateText'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      sect: (json['sect'] as String?) ?? '',
      honzon: (json['honzon'] as String?) ?? '',
      memo: (json['memo'] as String?) ?? '',
      albumImages: album,
      goshuinImages: normalized,
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
          .map((e) => TempleEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      // 新しい順（※並び替えは一覧側でも可）
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
      // setString は成功すると true を返す
      final ok = await prefs.setString(_listKey, payload);
      return ok;
    } catch (_) {
      // 容量超過などで例外になることがある
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

    final ok = await saveAll(all);

    // 失敗したら呼び出し側で通知したいので bool を返す
    return ok;
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
      albumImages: [],
      goshuinImages: [],
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
