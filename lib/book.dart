import 'dart:convert';
import 'dart:typed_data';

// ★ Web判定
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class BookPage extends StatefulWidget {
  const BookPage({super.key});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  // 基本情報
  final _templeNameController = TextEditingController(text: '普通寺');
  final _visitDateController = TextEditingController(text: '2025年11月28日');
  final _memoController = TextEditingController();

  // プロフィール追加項目
  final _addressController = TextEditingController();
  final _sectController = TextEditingController();
  final _honzonController = TextEditingController();

  final List<Uint8List> _albumImages = [];

  bool _selectionMode = false;
  final Set<int> _selectedIndexes = {};

  DateTime? _visitDate;

  static const _templeNameKey = 'templeName';
  static const _visitDateKey = 'visitDate';
  static const _memoKey = 'memo';
  static const _albumKey = 'album';

  static const _addressKey = 'address';
  static const _sectKey = 'sect';
  static const _honzonKey = 'honzon';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _templeNameController.dispose();
    _visitDateController.dispose();
    _memoController.dispose();
    _addressController.dispose();
    _sectController.dispose();
    _honzonController.dispose();
    super.dispose();
  }

  // ---------- 保存・読込 ----------
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    _templeNameController.text = prefs.getString(_templeNameKey) ?? '普通寺';

    final dateText = prefs.getString(_visitDateKey) ?? '2025年11月28日';
    _visitDateController.text = dateText;
    _visitDate = _parseDate(dateText);

    _memoController.text = prefs.getString(_memoKey) ?? '';
    _addressController.text = prefs.getString(_addressKey) ?? '';
    _sectController.text = prefs.getString(_sectKey) ?? '';
    _honzonController.text = prefs.getString(_honzonKey) ?? '';

    final list = prefs.getStringList(_albumKey);
    if (list != null) {
      _albumImages
        ..clear()
        ..addAll(list.map(base64Decode));
    }

    setState(() {});
  }

  Future<void> _save(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveAlbum() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _albumKey,
      _albumImages.map(base64Encode).toList(),
    );
  }

  // ---------- 日付 ----------
  String _formatDate(DateTime d) =>
      '${d.year}年${d.month.toString().padLeft(2, '0')}月${d.day.toString().padLeft(2, '0')}日';

  DateTime? _parseDate(String s) {
    final r = RegExp(r'(\d+)年(\d+)月(\d+)日');
    final m = r.firstMatch(s);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      _visitDate = picked;
      _visitDateController.text = _formatDate(picked);
      _save(_visitDateKey, _visitDateController.text);
      setState(() {});
    }
  }

  // ---------- Googleマップ（最終解） ----------
  void _openInMapsFinal() {
    final query = [
      _templeNameController.text.trim(),
      _addressController.text.trim(),
    ].where((e) => e.isNotEmpty).join(' ');

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('寺院名か所在地を入力してください')),
      );
      return;
    }

    final url =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';

    if (kIsWeb) {
      html.window.open(url, '_blank');
    }
  }

  // ---------- 画像 ----------
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;

    _albumImages.add(result.files.first.bytes!);
    await _saveAlbum();
    setState(() {});
  }

  void _openViewer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewer(images: _albumImages, index: index),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('御朱印帳'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share(
                '寺院：${_templeNameController.text}\n'
                '参拝日：${_visitDateController.text}\n'
                '所在地：${_addressController.text}\n'
                '宗派：${_sectController.text}\n'
                '御本尊：${_honzonController.text}\n\n'
                '${_memoController.text}',
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 寺院プロフィール
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  TextField(
                    controller: _visitDateController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: const InputDecoration(
                      labelText: '参拝日',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _templeNameController,
                    onChanged: (v) => _save(_templeNameKey, v),
                    decoration: const InputDecoration(labelText: '寺院名'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    onChanged: (v) => _save(_addressKey, v),
                    decoration: InputDecoration(
                      labelText: '所在地',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.location_on),
                        onPressed: _openInMapsFinal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sectController,
                    onChanged: (v) => _save(_sectKey, v),
                    decoration: const InputDecoration(labelText: '宗派'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _honzonController,
                    onChanged: (v) => _save(_honzonKey, v),
                    decoration: const InputDecoration(labelText: '御本尊'),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 24),

            /// メモ
            TextField(
              controller: _memoController,
              maxLines: 4,
              onChanged: (v) => _save(_memoKey, v),
              decoration: const InputDecoration(labelText: '参拝メモ'),
            ),

            const SizedBox(height: 24),

            /// アルバム
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('アルバム',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo),
                  label: const Text('写真追加'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _albumImages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _openViewer(i),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD0B48A)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(
                      _albumImages[i],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// フルスクリーンビューア
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.images, required this.index});

  final List<Uint8List> images;
  final int index;

  @override
  Widget build(BuildContext context) {
    final controller = PageController(initialPage: index);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: images.length,
        itemBuilder: (_, i) => Center(
          child: InteractiveViewer(
            child: Image.memory(images[i]),
          ),
        ),
      ),
    );
  }
}
