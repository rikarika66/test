import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
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
  final List<String>? templeIds;
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

  TempleEntry? _entry;

  // アルバム
  final List<Uint8List> _albumImages = [];

  // 御朱印（1枚）
  Uint8List? _goshuinImage;

  DateTime? _visitDate;

  bool _selectionMode = false;
  final Set<int> _selectedIndexes = <int>{};

  final _picker = ImagePicker();

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

    _goshuinImage = entry.goshuinImage;

    if (mounted) setState(() {});
  }

  Future<void> _saveNow() async {
    final e = _entry;
    if (e == null) return;

    e.templeName = _templeNameController.text;
    e.visitDateText = _visitDateController.text;
    e.memo = _memoController.text;

    e.address = _addressController.text;
    e.sect = _sectController.text;
    e.honzon = _honzonController.text;

    e.albumImages = List<Uint8List>.from(_albumImages);
    e.goshuinImage = _goshuinImage;

    await TempleStore.upsert(e);
  }

  // ---------- Kindle：前後ページ ----------
  bool get _canGoPrev =>
      !_selectionMode &&
      widget.templeIds != null &&
      widget.currentIndex != null &&
      widget.currentIndex! > 0;

  bool get _canGoNext =>
      !_selectionMode &&
      widget.templeIds != null &&
      widget.currentIndex != null &&
      widget.currentIndex! < widget.templeIds!.length - 1;

  Future<void> _goPrev() async {
    if (!_canGoPrev) return;
    final i = widget.currentIndex! - 1;
    await _replace(widget.templeIds![i], i, fromLeft: true);
  }

  Future<void> _goNext() async {
    if (!_canGoNext) return;
    final i = widget.currentIndex! + 1;
    await _replace(widget.templeIds![i], i, fromLeft: false);
  }

  Future<void> _replace(String id, int index, {required bool fromLeft}) async {
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => BookPage(
          templeId: id,
          templeIds: widget.templeIds,
          currentIndex: index,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final begin = fromLeft ? const Offset(-1, 0) : const Offset(1, 0);
          return SlideTransition(
            position: Tween(begin: begin, end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          );
        },
      ),
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
    if (picked == null) return;

    _visitDate = picked;
    _visitDateController.text = _formatDate(picked);
    await _saveNow();
    if (mounted) setState(() {});
  }

  // ---------- 地図 ----------
  Future<void> _openInMaps() async {
    final q = [
      _templeNameController.text.trim(),
      _addressController.text.trim(),
    ].where((e) => e.isNotEmpty).join(' ');

    if (q.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('寺院名か所在地を入力してください')),
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}',
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地図を開けませんでした')),
      );
    }
  }

  // ---------- 共有 ----------
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

  // ---------- 御朱印（1枚）：設定 ----------
  Future<void> _setGoshuinFromGallery() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery);
      if (x == null) return;

      final bytes = await x.readAsBytes();
      setState(() => _goshuinImage = bytes);
      await _saveNow();
    } catch (e) {
      debugPrint('御朱印（ギャラリー）エラー: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像の読み込みに失敗しました')),
      );
    }
  }

  Future<void> _setGoshuinFromCamera() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.camera);
      if (x == null) return;

      final bytes = await x.readAsBytes();
      setState(() => _goshuinImage = bytes);
      await _saveNow();
    } catch (e) {
      debugPrint('御朱印（カメラ）エラー: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('カメラの起動に失敗しました')),
      );
    }
  }

  Future<void> _clearGoshuin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('御朱印を削除しますか？'),
        content: const Text('この寺院の御朱印画像を削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _goshuinImage = null);
    await _saveNow();
  }

  void _openGoshuinViewer() {
    final bytes = _goshuinImage;
    if (bytes == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SingleImageViewer(bytes: bytes, title: '御朱印'),
      ),
    );
  }

  // ---------- アルバム：複数追加 ----------
  Future<void> _pickImages() async {
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

  // ---------- アルバム：選択モード ----------
  void _enterSelectionMode(int index) {
    setState(() {
      _selectionMode = true;
      _selectedIndexes.add(index);
    });
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedIndexes.contains(index)) {
        _selectedIndexes.remove(index);
      } else {
        _selectedIndexes.add(index);
      }
      if (_selectedIndexes.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIndexes.clear();
    });
  }

  Future<void> _deleteSelectedImages() async {
    if (_selectedIndexes.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('${_selectedIndexes.length}枚の写真を削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok != true) return;

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

  @override
  Widget build(BuildContext context) {
    final edge = MediaQuery.of(context).size.width * 0.10;

    final baseTitle = _templeNameController.text.isEmpty
        ? '御朱印帳'
        : '御朱印帳（${_templeNameController.text}）';

    return Scaffold(
      appBar: AppBar(
        title: Text(baseTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: '一覧',
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            tooltip: '共有',
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
                /// 寺院プロフィール
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
                            contentPadding: EdgeInsets.fromLTRB(12, 16, 48, 16),
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
                            contentPadding:
                                const EdgeInsets.fromLTRB(12, 16, 48, 16),
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

                /// 御朱印（縦長サムネで省スペース）
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '御朱印',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: '選ぶ',
                                  onPressed: _setGoshuinFromGallery,
                                  icon:
                                      const Icon(Icons.photo_library_outlined),
                                ),
                                IconButton(
                                  tooltip: '撮る',
                                  onPressed: _setGoshuinFromCamera,
                                  icon: const Icon(Icons.photo_camera_outlined),
                                ),
                                if (_goshuinImage != null)
                                  IconButton(
                                    tooltip: '削除',
                                    onPressed: _clearGoshuin,
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AspectRatio(
                          aspectRatio: 3 / 4,
                          child: GestureDetector(
                            onTap: _openGoshuinViewer,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFD0B48A)),
                                color: Colors.white,
                              ),
                              child: _goshuinImage == null
                                  ? const Center(
                                      child: Text(
                                        'まだ御朱印がありません\n右上のボタンで追加できます',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(13),
                                      child: Image.memory(
                                        _goshuinImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'タップで拡大表示',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                /// メモ
                TextField(
                  controller: _memoController,
                  maxLines: 4,
                  onChanged: (_) => _saveNow(),
                  decoration: const InputDecoration(labelText: '参拝メモ'),
                ),

                const SizedBox(height: 24),

                /// アルバム（削除ボタンは追加の隣）
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'アルバム',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
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
                        if (_selectionMode) ...[
                          IconButton(
                            tooltip: '選択解除',
                            icon: const Icon(Icons.close),
                            onPressed: _exitSelectionMode,
                          ),
                          IconButton(
                            tooltip: '削除',
                            icon: const Icon(Icons.delete),
                            onPressed: _selectedIndexes.isEmpty
                                ? null
                                : _deleteSelectedImages,
                          ),
                          const SizedBox(width: 6),
                        ],
                        ElevatedButton.icon(
                          onPressed: _selectionMode ? null : _pickImages,
                          icon: const Icon(Icons.photo),
                          label: const Text('追加'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_albumImages.isEmpty)
                  const Text('まだ写真がありません。右の「追加」から入れられます。')
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
                      final selected = _selectedIndexes.contains(i);

                      return GestureDetector(
                        onLongPress: () => _enterSelectionMode(i),
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelect(i);
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
                                  _albumImages[i],
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
                                        : Colors.blue.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            if (selected)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
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

          // 左端：前の寺院
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: edge,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _canGoPrev ? _goPrev : null,
            ),
          ),

          // 右端：次の寺院
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: edge,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _canGoNext ? _goNext : null,
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

class _SingleImageViewer extends StatelessWidget {
  const _SingleImageViewer({required this.bytes, required this.title});

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.memory(bytes),
        ),
      ),
    );
  }
}
