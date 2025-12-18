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
    required this.updatedAtMillis,
  });

  final String id;
  String templeName;
  String visitDateText; // 例: 2025年11月28日
  String address;
  String sect;
  String honzon;
  String memo;
  List<Uint8List> albumImages;
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
        'updatedAtMillis': updatedAtMillis,
      };

  static TempleEntry fromJson(Map<String, dynamic> json) {
    final images = (json['albumImages'] as List<dynamic>? ?? [])
        .map((e) => base64Decode(e as String))
        .toList();

    return TempleEntry(
      id: (json['id'] as String?) ?? _genId(),
      templeName: (json['templeName'] as String?) ?? '寺院',
      visitDateText: (json['visitDateText'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      sect: (json['sect'] as String?) ?? '',
      honzon: (json['honzon'] as String?) ?? '',
      memo: (json['memo'] as String?) ?? '',
      albumImages: images,
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

      // 新しい順で一覧に出す
      list.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<TempleEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = entries.map((e) => e.toJson()).toList();
    await prefs.setString(_listKey, jsonEncode(jsonList));
  }

  static Future<TempleEntry?> loadById(String id) async {
    final all = await loadAll();
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> upsert(TempleEntry entry) async {
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.id == entry.id);

    entry.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;

    if (idx >= 0) {
      all[idx] = entry;
    } else {
      all.insert(0, entry);
    }
    await saveAll(all);
  }

  static Future<void> deleteById(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await saveAll(all);
  }

  static TempleEntry newEntry() {
    final now = DateTime.now();
    final dateText = '${now.year}年${now.month}月${now.day}日';
    return TempleEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      templeName: '新しい寺院',
      visitDateText: dateText,
      address: '',
      sect: '',
      honzon: '',
      memo: '',
      albumImages: [],
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
