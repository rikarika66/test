import 'dart:convert';
import 'dart:typed_data';

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
  final TextEditingController _templeNameController =
      TextEditingController(text: '普通寺');
  final TextEditingController _visitDateController =
      TextEditingController(text: '2025年11月28日');
  final TextEditingController _memoController = TextEditingController();

  final List<Uint8List> _albumImages = [];

  bool _selectionMode = false;
  final Set<int> _selectedIndexes = <int>{};

  DateTime? _visitDate;

  static const String _templeNameKey = 'templeName';
  static const String _visitDateKey = 'visitDate';
  static const String _memoKey = 'memoText';
  static const String _albumKey = 'albumImages';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _templeNameController.dispose();
    _visitDateController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  // ------------------ 日付フォーマット ------------------
  String _formatDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}年$m月$d日';
  }

  DateTime? _parseJaDate(String s) {
    final reg = RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日$');
    final m = reg.firstMatch(s);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    _templeNameController.text = prefs.getString(_templeNameKey) ?? '普通寺';

    final savedDateText = prefs.getString(_visitDateKey) ?? '2025年11月28日';
    _visitDateController.text = savedDateText;
    _visitDate = _parseJaDate(savedDateText) ?? DateTime(2025, 11, 28);

    _memoController.text = prefs.getString(_memoKey) ?? '';

    final list = prefs.getStringList(_albumKey);
    if (list != null) {
      _albumImages
        ..clear()
        ..addAll(list.map((s) => base64Decode(s)));
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveTempleName(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_templeNameKey, v);
  }

  Future<void> _saveVisitDate(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_visitDateKey, v);
  }

  Future<void> _saveMemo(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_memoKey, v);
  }

  Future<void> _saveAlbumImages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _albumKey,
      _albumImages.map((e) => base64Encode(e)).toList(),
    );
  }

  // ------------------ カレンダーで参拝日を選択 ------------------
  Future<void> _pickVisitDate() async {
    final initial = _visitDate ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      // MaterialApp 側のローカライズ設定により日本語で表示される
    );

    if (picked != null) {
      setState(() {
        _visitDate = picked;
        _visitDateController.text = _formatDate(picked);
      });
      await _saveVisitDate(_visitDateController.text);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      setState(() {
        _albumImages.add(bytes);
      });
      await _saveAlbumImages();
    } catch (e) {
      debugPrint('画像読み込みエラー: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('画像の読み込みに失敗しました')));
    }
  }

  Future<void> _shareToSNS() async {
    final temple = _templeNameController.text.trim();
    final date = _visitDateController.text.trim();
    final memo = _memoController.text.trim();

    final buffer = StringBuffer();
    if (temple.isNotEmpty) buffer.writeln('寺院：$temple');
    if (date.isNotEmpty) buffer.writeln('参拝日：$date');
    if (memo.isNotEmpty) buffer.writeln('\n参拝メモ：\n$memo');

    buffer.writeln('\n#御朱印 #御朱印巡り');

    await SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  void _handleTapUp(TapUpDetails d) {
    final width = MediaQuery.of(context).size.width;
    if (d.localPosition.dx < width * 0.5) Navigator.of(context).pop();
  }

  Future<void> _deleteSelectedImages() async {
    if (_selectedIndexes.isEmpty) return;

    setState(() {
      final sorted = _selectedIndexes.toList()..sort((a, b) => b.compareTo(a));
      for (final i in sorted) {
        if (i >= 0 && i < _albumImages.length) {
          _albumImages.removeAt(i);
        }
      }
      _selectedIndexes.clear();
      _selectionMode = false;
    });

    await _saveAlbumImages();
  }

  // ------------------ フルスクリーンビューアを開く ------------------
  void _openImageViewer(int initialIndex) {
    if (_albumImages.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageViewerPage(
          images: _albumImages,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTapUp,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F2E9),
          image: DecorationImage(
            image: AssetImage('assets/images/wagara1.png'),
            repeat: ImageRepeat.repeat,
            fit: BoxFit.none,
            opacity: 0.18,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF3E2E20),
            title: const Text(
              '御朱印帳',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                onPressed: _shareToSNS,
                icon: const Icon(Icons.ios_share),
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
                  color: const Color(0xFFFFFBF3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFFE2D4BF)),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '寺院プロフィール',
                            style: TextStyle(
                              color: Color(0xFFB3453C),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _templeNameController,
                          decoration: const InputDecoration(
                            labelText: '寺院名',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: _saveTempleName,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _visitDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: '参拝日',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: _pickVisitDate,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                /// メモ欄
                const Text(
                  '参拝メモ',
                  style: TextStyle(
                    color: Color(0xFFB3453C),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _memoController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: '参拝した内容や感想を書いてください…',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: _saveMemo,
                ),

                const SizedBox(height: 24),

                /// アルバムヘッダー
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'アルバム',
                      style: TextStyle(
                        color: Color(0xFFB3453C),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        if (_selectionMode)
                          TextButton(
                            onPressed: _selectedIndexes.isEmpty
                                ? null
                                : _deleteSelectedImages,
                            child: const Text(
                              "選択削除",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectionMode = !_selectionMode;
                              _selectedIndexes.clear();
                            });
                          },
                          child: Text(
                            _selectionMode ? "キャンセル" : "選択",
                            style: const TextStyle(color: Color(0xFFB3453C)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton.icon(
                          onPressed: _selectionMode ? null : _pickImage,
                          icon: const Icon(Icons.photo),
                          label: const Text("写真追加"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD26B4E),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                /// アルバム一覧（2列グリッド）
                if (_albumImages.isEmpty)
                  const Text(
                    'まだ写真がありません。「写真追加」ボタンから画像を選んでください。',
                    style: TextStyle(color: Color(0xFF7A6A59)),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _albumImages.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // ★ 3列に変更
                      crossAxisSpacing: 8, // 列の間隔（少し狭め）
                      mainAxisSpacing: 8, // 行の間隔
                      childAspectRatio: 1.0, // 正方形に近く
                    ),
                    itemBuilder: (context, index) {
                      final bytes = _albumImages[index];
                      final selected = _selectedIndexes.contains(index);

                      return GestureDetector(
                        onTap: () {
                          if (_selectionMode) {
                            setState(() {
                              if (selected) {
                                _selectedIndexes.remove(index);
                              } else {
                                _selectedIndexes.add(index);
                              }
                            });
                          } else {
                            _openImageViewer(index);
                          }
                        },
                        child: Stack(
                          children: [
                            // ★ 角丸＋薄い枠線の「写真フレーム」
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      const Color(0xFFD0B48A), // ★ 少し濃いベージュ系に変更
                                  width: 1,
                                ),
                                color: Colors.white,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.memory(
                                  bytes,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                            ),

                            // 選択中オーバーレイ（朱色）
                            if (_selectionMode)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFB3453C)
                                            .withOpacity(0.30)
                                        : const Color(0xFFB3453C)
                                            .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ================== フルスクリーン画像ビューア ==================

class _ImageViewerPage extends StatefulWidget {
  const _ImageViewerPage({
    required this.images,
    required this.initialIndex,
  });

  final List<Uint8List> images;
  final int initialIndex;

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / $total'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        onPageChanged: (i) {
          setState(() {
            _currentIndex = i;
          });
        },
        itemCount: widget.images.length,
        itemBuilder: (_, index) {
          final bytes = widget.images[index];
          return Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.memory(bytes),
            ),
          );
        },
      ),
    );
  }
}
