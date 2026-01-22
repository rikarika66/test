import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageStorage {
  ImageStorage._();

  /// 画像の保存先ルート（アプリ内部）
  static Future<Directory> _rootDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(dir.path, 'goshuin_images'));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  /// 寺院IDごとの保存フォルダ
  static Future<Directory> _entryDir(String entryId) async {
    final root = await _rootDir();
    final d = Directory(p.join(root.path, entryId));
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  /// bytes をファイル保存して「パス」を返す
  /// kind: 'album' / 'goshuin' など識別用
  /// ext : 'jpg' 'png' など。分からなければ 'jpg' 推奨
  static Future<String> saveBytes({
    required String entryId,
    required Uint8List bytes,
    required String kind,
    String ext = 'jpg',
  }) async {
    final dir = await _entryDir(entryId);
    final safeExt = ext.replaceAll('.', '').trim();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filename = '${kind}_$ts.$safeExt';
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// 既存ファイルをアプリ内へコピーしてパスを返す（FilePicker等で便利）
  static Future<String> copyFromPath({
    required String entryId,
    required String sourcePath,
    required String kind,
  }) async {
    final src = File(sourcePath);
    if (!await src.exists()) return '';

    final dir = await _entryDir(entryId);
    final ext = p.extension(sourcePath).replaceAll('.', '');
    final safeExt = (ext.isEmpty) ? 'jpg' : ext;

    final ts = DateTime.now().millisecondsSinceEpoch;
    final filename = '${kind}_$ts.$safeExt';
    final dst = File(p.join(dir.path, filename));
    await src.copy(dst.path);
    return dst.path;
  }

  /// ファイル削除（失敗しても落ちない）
  static Future<void> deleteFile(String path) async {
    if (path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  /// entryIdフォルダごと削除（寺院データ削除時に使う）
  static Future<void> deleteEntryDir(String entryId) async {
    try {
      final dir = await _entryDir(entryId);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// 存在チェック（UIで Image.file に渡す前に安全策）
  static Future<bool> exists(String path) async {
    if (path.isEmpty) return false;
    try {
      return File(path).exists();
    } catch (_) {
      return false;
    }
  }
}
