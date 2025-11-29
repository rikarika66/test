import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html; // ★ Web専用：ブラウザのファイル選択＆表示用

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookPage extends StatefulWidget {
  const BookPage({super.key});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  final TextEditingController _memoController = TextEditingController();

  // 画像は Data URL 文字列で保持（"data:image/png;base64,..."）
  final List<String> _albumImageUrls = [];

  // SharedPreferences のキー
  static const String _memoKey = 'memoText';
  static const String _albumKey = 'albumImageUrls';

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

  /// アルバム画像読み込み（Data URL のリスト）
  Future<void> _loadAlbumImages() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? urls = prefs.getStringList(_albumKey);

    if (!mounted) return;

    if (urls != null && urls.isNotEmpty) {
      setState(() {
        _albumImageUrls
          ..clear()
          ..addAll(urls);
      });
    }
  }

  /// アルバム画像保存（Data URL のリスト）
  Future<void> _saveAlbumImages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_albumKey, _albumImageUrls);
  }

  /// Web向け：ブラウザのファイル選択ダイアログを使って画像を選ぶ
  Future<void> _pickImage() async {
    try {
      final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
      uploadInput.click(); // 写真選択ダイアログを開く

      uploadInput.onChange.first.then((event) async {
        final file = uploadInput.files?.first;
        if (file == null) return;

        final reader = html.FileReader();
        // Data URL（"data:image/...;base64,..."）として読み込む
        reader.readAsDataUrl(file);

        await reader.onLoadEnd.first;

        final result = reader.result;
        if (result is String) {
          // Data URL 文字列として結果が返る
          setState(() {
            _albumImageUrls.add(result);
          });

          await _saveAlbumImages();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('画像の形式を読み取れませんでした'),
            ),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('画像読み込み中にエラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('画像の読み込みに失敗しました: $e'),
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
            if (_albumImageUrls.isEmpty)
              const Text(
                "まだ写真がありません。右の「写真追加」からアルバムの写真を選んでください。",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _albumImageUrls.map((url) {
                  return GestureDetector(
                    onTap: () {
                      // 拡大表示
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
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
