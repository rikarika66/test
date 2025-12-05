import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// ------------------------------
/// テーマ定義
/// ------------------------------
class BookPageTheme {
  final Color bgTop;
  final Color bgBottom;
  final Color cardColor;
  final Color cardBorder;
  final Color sectionTitle;
  final Color mainText;
  final Color subText;
  final Color accent;
  final Color chipBg;
  final Color chipText;

  const BookPageTheme({
    required this.bgTop,
    required this.bgBottom,
    required this.cardColor,
    required this.cardBorder,
    required this.sectionTitle,
    required this.mainText,
    required this.subText,
    required this.accent,
    required this.chipBg,
    required this.chipText,
  });
}

/// A：やわらかい生成り × 朱色 和モダン
const BookPageTheme softWarmTheme = BookPageTheme(
  bgTop: Color(0xFFF1E4D2), // 明るい生成り
  bgBottom: Color(0xFFE6D4BD), // 少し濃い生成り
  cardColor: Color(0xFFFFFBF3),
  cardBorder: Color(0xFFE2D4BF),
  sectionTitle: Color(0xFFB3453C),
  mainText: Color(0xFF3E2E20),
  subText: Color(0xFF7A6A59),
  accent: Color(0xFFD26B4E),
  chipBg: Color(0xFFFFF0DA),
  chipText: Color(0xFF8A4A2D),
);

/// 参考用：少し渋めの和モダン（使いたくなったら切り替え）
const BookPageTheme deepWarmTheme = BookPageTheme(
  bgTop: Color(0xFFF3E8D7),
  bgBottom: Color(0xFFE3D2BE),
  cardColor: Color(0xFFFFF7EB),
  cardBorder: Color(0xFFD3C2AA),
  sectionTitle: Color(0xFF8C2E2E),
  mainText: Color(0xFF33251A),
  subText: Color(0xFF6B5A4A),
  accent: Color(0xFFC85A4A),
  chipBg: Color(0xFFF5E0C5),
  chipText: Color(0xFF7A432B),
);

class BookPage extends StatefulWidget {
  const BookPage({super.key});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  // ★ テーマ切り替え（必要なら deepWarmTheme に変更）
  final BookPageTheme _theme = softWarmTheme;

  // 入力コントローラ
  final TextEditingController _templeNameController =
      TextEditingController(text: "普通寺");
  final TextEditingController _visitDateController =
      TextEditingController(text: "2025年11月28日");
  final TextEditingController _memoController = TextEditingController();

  // 写真データ（メモリ上）
  final List<Uint8List> _albumImages = [];

  // 選択モード
  bool _selectionMode = false;
  final Set<int> _selectedIndexes = <int>{};

  // SharedPreferencesキー
  static const String _templeNameKey = 'templeName';
  static const String _visitDateKey = 'visitDate';
  static const String _memoKey = 'memoText';
  static const String _albumKey = 'albumImages';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    _templeNameController.text = prefs.getString(_templeNameKey) ?? "普通寺";
    _visitDateController.text = prefs.getString(_visitDateKey) ?? "2025年11月28日";
    _memoController.text = prefs.getString(_memoKey) ?? "";

    final List<String>? base64List = prefs.getStringList(_albumKey);
    if (base64List != null) {
      _albumImages
        ..clear()
        ..addAll(base64List.map((s) => base64Decode(s)));
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveTempleName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_templeNameKey, value);
  }

  Future<void> _saveVisitDate(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_visitDateKey, value);
  }

  Future<void> _saveMemo(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_memoKey, value);
  }

  Future<void> _saveAlbumImages() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _albumImages.map((e) => base64Encode(e)).toList();
    await prefs.setStringList(_albumKey, list);
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
      if (!mounted) return;
      debugPrint('画像選択中に例外: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('画像の読み込みに失敗しました'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIndexes.clear();
    });
  }

  void _onTapImage(int index, Uint8List bytes) {
    if (_selectionMode) {
      setState(() {
        if (_selectedIndexes.contains(index)) {
          _selectedIndexes.remove(index);
        } else {
          _selectedIndexes.add(index);
        }
      });
    } else {
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
    }
  }

  Future<void> _deleteSelectedImages() async {
    if (_selectedIndexes.isEmpty) return;

    setState(() {
      final sorted = _selectedIndexes.toList()
        ..sort((a, b) => b.compareTo(a)); // 後ろから削除
      for (final idx in sorted) {
        if (idx >= 0 && idx < _albumImages.length) {
          _albumImages.removeAt(idx);
        }
      }
      _selectedIndexes.clear();
      _selectionMode = false;
    });

    await _saveAlbumImages();
  }

  /// 寺院名＋参拝日＋メモ＋（スマホ時は写真1枚目）をSNSに共有
  Future<void> _shareToSNS() async {
    final temple = _templeNameController.text.trim();
    final date = _visitDateController.text.trim();
    final memo = _memoController.text.trim();

    final buffer = StringBuffer();
    if (temple.isNotEmpty) buffer.writeln('寺院：$temple');
    if (date.isNotEmpty) buffer.writeln('参拝日：$date');

    if (memo.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('参拝メモ：');
      buffer.writeln(memo);
    }

    buffer.writeln();
    buffer.writeln('#御朱印 #御朱印帳');

    final text = buffer.toString();

    // Web または写真がない場合はテキストのみ共有
    if (kIsWeb || _albumImages.isEmpty) {
      await SharePlus.instance.share(
        ShareParams(text: text),
      );
      return;
    }

    // スマホアプリでは1枚目の写真も一緒に共有
    final bytes = _albumImages.first;
    final xFile = XFile.fromData(
      bytes,
      name: 'goshuin.png',
      mimeType: 'image/png',
    );

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: [xFile],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- 背景グラデーション ---
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_theme.bgTop, _theme.bgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // --- 七宝柄 overlay（継ぎ目なし・1枚を全画面に） ---
          Positioned.fill(
            child: Opacity(
              opacity: 0.18, // 濃さはお好みで調整
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xFFB08A4A), // 七宝の線を少し濃い茶色に
                  BlendMode.srcATop,
                ),
                child: Image.asset(
                  'assets/images/wagara1.png',
                  fit: BoxFit.cover, // 1枚を画面全体に敷く
                ),
              ),
            ),
          ),

          // --- メインUI（透明なScaffoldで上に乗せる） ---
          Positioned.fill(
            child: SafeArea(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  foregroundColor: _theme.mainText,
                  title: Text(
                    '御朱印帳',
                    style: TextStyle(
                      color: _theme.mainText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.ios_share),
                      tooltip: 'SNSにシェア',
                      onPressed: _shareToSNS,
                    ),
                  ],
                ),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- 寺院プロフィールカード ---
                      Card(
                        color: _theme.cardColor,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: _theme.cardBorder),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // タイトルチップ
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _theme.chipBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "寺院プロフィール",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _theme.chipText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // 寺院名
                              TextField(
                                controller: _templeNameController,
                                decoration: InputDecoration(
                                  labelText: "寺院名",
                                  labelStyle: TextStyle(color: _theme.subText),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _theme.cardBorder,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _theme.accent,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                ),
                                onChanged: _saveTempleName,
                              ),
                              const SizedBox(height: 12),

                              // 参拝日
                              TextField(
                                controller: _visitDateController,
                                decoration: InputDecoration(
                                  labelText: "参拝日（例：2025年11月28日）",
                                  labelStyle: TextStyle(color: _theme.subText),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _theme.cardBorder,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _theme.accent,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                ),
                                onChanged: _saveVisitDate,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // --- メモ欄 ---
                      Text(
                        "参拝メモ",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _theme.sectionTitle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _memoController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: "参拝した感想や出来事を書いてください…",
                          hintStyle: TextStyle(color: _theme.subText),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: _theme.cardBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: _theme.accent,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                        ),
                        onChanged: _saveMemo,
                      ),

                      const SizedBox(height: 24),

                      // --- アルバムヘッダー ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "アルバム",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _theme.sectionTitle,
                            ),
                          ),
                          Row(
                            children: [
                              if (_selectionMode)
                                TextButton(
                                  onPressed: _selectedIndexes.isEmpty
                                      ? null
                                      : _deleteSelectedImages,
                                  child: Text(
                                    "選択削除",
                                    style: TextStyle(color: _theme.accent),
                                  ),
                                ),
                              TextButton(
                                onPressed: _albumImages.isEmpty
                                    ? null
                                    : _toggleSelectionMode,
                                child: Text(
                                  _selectionMode ? "選択解除" : "選択",
                                  style: TextStyle(
                                    color: _theme.sectionTitle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton.icon(
                                onPressed: _selectionMode ? null : _pickImage,
                                icon: const Icon(Icons.photo),
                                label: const Text("写真追加"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _theme.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // --- アルバム一覧 ---
                      if (_albumImages.isEmpty)
                        Text(
                          "まだ写真がありません。右上の「写真追加」からアルバムの写真を選んでください。",
                          style: TextStyle(
                            fontSize: 14,
                            color: _theme.subText,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(_albumImages.length, (index) {
                            final bytes = _albumImages[index];
                            final isSelected = _selectedIndexes.contains(index);

                            return GestureDetector(
                              onTap: () => _onTapImage(index, bytes),
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.memory(
                                        bytes,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  if (_selectionMode)
                                    Positioned.fill(
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          color: isSelected
                                              ? Colors.black.withOpacity(0.35)
                                              : Colors.black.withOpacity(0.18),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Align(
                                          alignment: Alignment.topRight,
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Icon(
                                              isSelected
                                                  ? Icons.check_circle
                                                  : Icons.circle_outlined,
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
