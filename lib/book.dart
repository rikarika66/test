import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookPage extends StatefulWidget {
  const BookPage({super.key});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  final TextEditingController _memoController = TextEditingController();

  // 追加した写真（メモリ上＆保存用）
  final List<Uint8List> _albumImages = [];

  // SharedPreferences のキー
  static const String _memoKey = 'memoText';
  static const String _albumKey = 'albumImages';

  @override
  void initState() {
    super.initState();
    _loadMemo();
    _loadAlbumImages();
  }

  /// メモ読み込み
  Future<void> _loadMemo() async {
    final prefs = await SharedPreferences.getInstance();
    _memoController.text = prefs.getString(_memoKey) ?? '';
  }

  /// メモ保存
  Future<void> _saveMemo(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_memoKey, text);
  }

  /// アルバム画像を読み込み
  Future<void> _loadAlbumImages() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? base64List = prefs.getStringList(_albumKey);

    if (base64List != null && base64List.isNotEmpty) {
      setState(() {
        _albumImages
          ..clear()
          ..addAll(
            base64List.map((s) => base64Decode(s)),
          );
      });
    }
  }

  /// アルバム画像を保存
  Future<void> _saveAlbumImages() async {
    final prefs = await SharedPreferences.getInstance();
    final base64List =
        _albumImages.map((bytes) => base64Encode(bytes)).toList();
    await prefs.setStringList(_albumKey, base64List);
  }

  /// 画像を1枚選択
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) return;

      setState(() {
        _albumImages.add(fileBytes);
      });

      await _saveAlbumImages();
    } catch (e) {
      if (!mounted) return;

      debugPrint('画像選択中に例外が発生しました: $e');

      // ★ ここが重要：const を付けない ＋ $e を含める
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('画像の読み込みに失敗しました: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const templeName = "普通寺";
    const templeAddress = "愛媛県松山市 〇〇町";
    const visitDate = "参拝日: 2025年11月28日";

    return Scaffold(
      appBar: AppBar(
        title: const Text('御朱印帳'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 寺院プロフィール
            Text(
              templeName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(templeAddress, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(visitDate, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),

            /// メモ欄
            const Text(
              "参拝メモ",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _memoController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "参拝した感想や出来事を書いてください…",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: _saveMemo,
            ),
            const SizedBox(height: 24),

            /// アルバムヘッダー＋ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "アルバム",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo),
                  label: const Text("写真追加"),
                ),
              ],
            ),
            const SizedBox(height: 12),

            /// 写真一覧
            if (_albumImages.isEmpty)
              const Text(
                "まだ写真がありません。右の「写真追加」からアルバムの写真を選んでください。",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _albumImages.map((bytes) {
                  return GestureDetector(
                    onTap: () {
                      // 拡大表示
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        bytes,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
