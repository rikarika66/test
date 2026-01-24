import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageStorage {
  static const _albumDir = 'album';
  static const _goshuinDir = 'goshuin';

  static Future<Directory> _rootDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> _albumRoot() async {
    final dir = Directory(p.join((await _rootDir()).path, _albumDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> _goshuinRoot() async {
    final dir = Directory(p.join((await _rootDir()).path, _goshuinDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// ===== 保存（元画像＋サムネ）=====
  static Future<String> saveImage(
    Uint8List bytes, {
    required bool isGoshuin,
  }) async {
    final dir = isGoshuin ? await _goshuinRoot() : await _albumRoot();
    final baseName = DateTime.now().millisecondsSinceEpoch.toString();

    final originalPath = p.join(dir.path, '$baseName.jpg');
    final thumbPath = p.join(dir.path, '${baseName}_thumb.jpg');

    // 元画像保存
    await File(originalPath).writeAsBytes(bytes, flush: true);

    // サムネ生成
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      final thumb = img.copyResize(decoded, width: 300);
      final thumbBytes = img.encodeJpg(thumb, quality: 80);
      await File(thumbPath).writeAsBytes(thumbBytes, flush: true);
    }

    return originalPath;
  }

  /// ===== 読み込み =====
  static Future<Uint8List?> loadImage(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static Future<Uint8List?> loadThumbnail(String originalPath) async {
    final thumbPath = _thumbPath(originalPath);
    final file = File(thumbPath);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static String _thumbPath(String originalPath) {
    final dir = p.dirname(originalPath);
    final name = p.basenameWithoutExtension(originalPath);
    return p.join(dir, '${name}_thumb.jpg');
  }

  /// ===== 削除 =====
  static Future<void> deleteImage(String path) async {
    final original = File(path);
    final thumb = File(_thumbPath(path));

    if (await original.exists()) {
      await original.delete();
    }
    if (await thumb.exists()) {
      await thumb.delete();
    }
  }

  static Future<void> deleteImages(List<String> paths) async {
    for (final p in paths) {
      await deleteImage(p);
    }
  }
}
