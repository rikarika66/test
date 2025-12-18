import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'temple_store.dart';

class BookPage extends StatefulWidget {
  const BookPage({
    super.key,
    required this.templeId,
    this.templeIds,
    this.currentIndex,
  });

  final String templeId;

  /// 一覧の並び（前後ページ用）
  final List<String>? templeIds;

  /// 一覧での現在位置（前後ページ用）
  final int? currentIndex;

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  final _templeNameController = TextEditingController();
  final _visitDateController = TextEditingController();
  final _memoController = TextEditingController();

  final _addressController = TextEditingController();
  final _sectController = TextEditingController();
  final _honzonController = TextEditingController();

  final List<Uint8List> _albumImages = [];
  DateTime? _visitDate;
  TempleEntry? _entry;

  bool _selectionMode = false;
  final Set<int> _selectedIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    _loadEntry();
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

  Future<void> _loadEntry() async {
    final loaded = await TempleStore.loadById(widget.templeId);
    final entry = loaded ?? TempleStore.newEntry();

    _entry = entry;

    _templeNameController.text = entry.templeName;
    _visitDateController.text = entry.visitDateText;
    _memoController.text = entry.memo;

    _addressController.text = entry.address;
    _sectController.text = entry.sect;
    _honzonController.text = entry.honzon;

    _visitDate = _parseDate(entry.visitDateText);

    _albumImages
      ..clear()
      ..addAll(entry.albumImages);

    if (mounted) setState(() {});
  }

  Future<void> _saveNow() async {
    final entry = _entry;
    if (entry == null) return;

    entry.templeName = _templeNameController.text;
    entry.visitDateText = _visitDateController.text;
    entry.memo = _memoController.text;

    entry.address = _addressController.text;
    entry.sect = _sectController.text;
    entry.honzon = _honzonController.text;

    entry.albumImages = List<Uint8List>.from(_albumImages);

    await TempleStore.upsert(entry);
  }

  // ---------- Kindle：前後ページ判定 ----------
  bool get _hasPagerInfo =>
      widget.templeIds != null &&
      widget.currentIndex != null &&
      widget.currentIndex! >= 0;

  bool get _canGoNext =>
      _hasPagerInfo && widget.currentIndex! < widget.templeIds!.length - 1;

  bool get _canGoPrev => _hasPagerInfo && widget.currentIndex! > 0;

  // ---------- Kindle：前へ（左端） ----------
  Future<void> _goPrevByLeftTap() async {
    if (_selectionMode) return;
    if (!_canGoPrev) return;

    final ids = widget.templeIds!;
    final prevIndex = widget.currentIndex! - 1;
    final prevId = ids[prevIndex];

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => BookPage(
          templeId: prevId,
          templeIds: ids,
          currentIndex: prevIndex,
        ),
        transitionsBuilder: (_, animation, __, child) {
          // ★ 前へ：左から入る（逆向き）
          final offset = Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          );
          return SlideTransition(position: offset, child: child);
        },
      ),
    );
  }

  // ---------- Kindle：次へ（右端） ----------
  Future<void> _goNextByRightTap() async {
    if (_selectionMode) return;
    if (!_canGoNext) return;

    final ids = widget.templeIds!;
    final nextIndex = widget.currentIndex! + 1;
    final nextId = ids[nextIndex];

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => BookPage(
          templeId: nextId,
          templeIds: ids,
          currentIndex: nextIndex,
        ),
        transitionsBuilder: (_, animation, __, child) {
          // ★ 次へ：右から入る
          final offset = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          );
          return SlideTransition(position: offset, child: child);
        },
      ),
    );
  }

  // ---------- 一覧に戻る（右上ボタン） ----------
  void _backToList() {
    Navigator.of(context).pop();
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
      await _saveNow();
      if (mounted) setState(() {});
    }
  }

  // ---------- 地図 ----------
  Future<void> _openInMaps() async {
    final query = [
      _templeNameController.text.trim(),
      _addressController.text.trim(),
    ].where((e) => e.isNotEmpty).join(' ');

    if (query.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('寺院名か所在地を入力してください')),
      );
      return;
    }

    final appleUri =
        Uri.parse('https://maps.apple.com/?q=${Uri.encodeComponent(query)}');
    final googleUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );

    final okApple = await launchUrl(appleUri, mode: LaunchMode.platformDefault);
    if (okApple) return;

    final okGoogle =
        await launchUrl(googleUri, mode: LaunchMode.platformDefault);
    if (okGoogle) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('地図を開けませんでした')),
    );
  }

  // ---------- 画像 ----------
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked =
        result.files.map((f) => f.bytes).whereType<Uint8List>().toList();
    if (picked.isEmpty) return;

    setState(() {
      _albumImages.addAll(picked);
    });

    await _saveNow();
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

    await _saveNow();
  }

  void _openViewer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewer(images: _albumImages, index: index),
      ),
    );
  }

  Future<void> _share() async {
    final text = StringBuffer()
      ..writeln('寺院：${_templeNameController.text}')
      ..writeln('参拝日：${_visitDateController.text}')
      ..writeln('所在地：${_addressController.text}')
      ..writeln('宗派：${_sectController.text}')
      ..writeln('御本尊：${_honzonController.text}')
      ..writeln()
      ..writeln(_memoController.text)
      ..writeln()
      ..writeln('#御朱印 #御朱印巡り');
    Share.share(text.toString());
  }

  @override
  Widget build(BuildContext context) {
    final title = _templeNameController.text.isEmpty
        ? '御朱印帳'
        : '御朱印帳（${_templeNameController.text}）';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: false, // ←は出さない（Kindle方式）
        actions: [
          // 一覧に戻る
          IconButton(
            tooltip: '一覧',
            icon: const Icon(Icons.list),
            onPressed: _backToList,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _share,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
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
                          onChanged: (_) => _saveNow(),
                          decoration: const InputDecoration(labelText: '寺院名'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          onChanged: (_) => _saveNow(),
                          decoration: InputDecoration(
                            labelText: '所在地',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.location_on),
                              onPressed: _openInMaps,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _sectController,
                          onChanged: (_) => _saveNow(),
                          decoration: const InputDecoration(labelText: '宗派'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _honzonController,
                          onChanged: (_) => _saveNow(),
                          decoration: const InputDecoration(labelText: '御本尊'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _memoController,
                  maxLines: 4,
                  onChanged: (_) => _saveNow(),
                  decoration: const InputDecoration(labelText: '参拝メモ'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'アルバム',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectionMode) ...[
                          const SizedBox(width: 10),
                          Text(
                            '${_selectedIndexes.length}枚選択',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        if (_selectionMode)
                          TextButton(
                            onPressed: _selectedIndexes.isEmpty
                                ? null
                                : _deleteSelectedImages,
                            child: const Text(
                              '選択削除',
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
                          child: Text(_selectionMode ? 'キャンセル' : '選択'),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: _selectionMode ? null : _pickImage,
                          icon: const Icon(Icons.photo),
                          label: const Text('写真追加'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_albumImages.isEmpty)
                  const Text('まだ写真がありません。「写真追加」から追加できます。')
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _albumImages.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (_, i) {
                      final bytes = _albumImages[i];
                      final selected = _selectedIndexes.contains(i);

                      return GestureDetector(
                        onTap: () {
                          if (_selectionMode) {
                            setState(() {
                              if (selected) {
                                _selectedIndexes.remove(i);
                              } else {
                                _selectedIndexes.add(i);
                              }
                            });
                          } else {
                            _openViewer(i);
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFD0B48A)),
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
                            if (_selectionMode)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.blue.withOpacity(0.35)
                                        : Colors.blue.withOpacity(0.12),
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

          // 左端：前の寺院へ
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.18,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _canGoPrev ? _goPrevByLeftTap : null,
            ),
          ),

          // 右端：次の寺院へ
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.18,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _canGoNext ? _goNextByRightTap : null,
            ),
          ),
        ],
      ),
    );
  }
}

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
