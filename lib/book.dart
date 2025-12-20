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

  // 御朱印（最大2枚運用）
  final List<Uint8List> _goshuinImages = [];

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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

    _goshuinImages
      ..clear()
      ..addAll(entry.goshuinImages);

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
    e.goshuinImages = _goshuinImages.take(2).toList();

    await TempleStore.upsert(e);
  }

  /// ★「保存できたか」を再読み込みで検証する（誤警告を消すため）
  Future<bool> _saveNowVerified({bool verifyGoshuin = true}) async {
    final e = _entry;
    if (e == null) return false;

    // まず通常保存（例外が出ても検証する）
    try {
      await _saveNow();
    } catch (err) {
      debugPrint('saveNow exception (but will verify): $err');
    }

    // 検証：同IDを再読み込みして、必要箇所が残っているか
    try {
      final reloaded = await TempleStore.loadById(e.id);
      if (reloaded == null) return false;

      if (!verifyGoshuin) return true;

      // 御朱印の「枚数」と「各サイズ」が一致すればOK扱い
      final nowList = _goshuinImages
          .where((b) => b.isNotEmpty)
          .map((b) => b.length)
          .toList();
      final savedList = reloaded.goshuinImages
          .where((b) => b.isNotEmpty)
          .map((b) => b.length)
          .toList();

      if (nowList.length != savedList.length) return false;
      for (var i = 0; i < nowList.length; i++) {
        if (nowList[i] != savedList[i]) return false;
      }
      return true;
    } catch (err) {
      debugPrint('save verify exception: $err');
      return false;
    }
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

    final ok = await _saveNowVerified(verifyGoshuin: false);
    if (!ok) _snack('参拝日は表示できましたが、保存確認に失敗しました');

    if (mounted) setState(() {});
  }

  // ---------- 地図 ----------
  Future<void> _openInMaps() async {
    final q = [
      _templeNameController.text.trim(),
      _addressController.text.trim(),
    ].where((e) => e.isNotEmpty).join(' ');

    if (q.isEmpty) {
      _snack('寺院名か所在地を入力してください');
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}',
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('地図を開けませんでした');
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

  // ---------- 御朱印（2枠）：ユーティリティ ----------
  void _setSlotBytes(int slot, Uint8List bytes) {
    while (_goshuinImages.length <= slot) {
      _goshuinImages.add(Uint8List(0));
    }
    _goshuinImages[slot] = bytes;

    while (_goshuinImages.isNotEmpty && _goshuinImages.last.isEmpty) {
      _goshuinImages.removeLast();
    }

    if (_goshuinImages.length > 2) {
      _goshuinImages.removeRange(2, _goshuinImages.length);
    }
  }

  // ---------- 御朱印（2枠）：読み込み ----------
  Future<void> _setGoshuinFromGallery(int slot) async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery);
      if (x == null) return;

      final bytes = await x.readAsBytes();
      setState(() => _setSlotBytes(slot, bytes));
    } catch (e) {
      debugPrint('御朱印（ギャラリー）読み込みエラー: $e');
      _snack('画像の読み込みに失敗しました');
      return;
    }

    final ok = await _saveNowVerified(verifyGoshuin: true);
    if (!ok) _snack('画像は表示できましたが、保存確認に失敗しました');
  }

  Future<void> _setGoshuinFromCamera(int slot) async {
    try {
      final x = await _picker.pickImage(source: ImageSource.camera);
      if (x == null) return;

      final bytes = await x.readAsBytes();
      setState(() => _setSlotBytes(slot, bytes));
    } catch (e) {
      debugPrint('御朱印（カメラ）読み込みエラー: $e');
      _snack('画像の読み込みに失敗しました');
      return;
    }

    final ok = await _saveNowVerified(verifyGoshuin: true);
    if (!ok) _snack('画像は表示できましたが、保存確認に失敗しました');
  }

  Future<void> _clearGoshuin(int slot) async {
    final has = slot < _goshuinImages.length && _goshuinImages[slot].isNotEmpty;
    if (!has) return;

    final okDialog = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('御朱印${slot + 1}を削除します。'),
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
    if (okDialog != true) return;

    setState(() {
      _goshuinImages[slot] = Uint8List(0);
      while (_goshuinImages.isNotEmpty && _goshuinImages.last.isEmpty) {
        _goshuinImages.removeLast();
      }
    });

    final ok = await _saveNowVerified(verifyGoshuin: true);
    if (!ok) _snack('削除は反映されましたが、保存確認に失敗しました');
  }

  void _openGoshuinViewer(int slot) {
    if (slot >= _goshuinImages.length) return;
    final bytes = _goshuinImages[slot];
    if (bytes.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SingleImageViewer(bytes: bytes, title: '御朱印'),
      ),
    );
  }

  Widget _goshuinSlot({required int slot, required String label}) {
    final has = slot < _goshuinImages.length && _goshuinImages[slot].isNotEmpty;
    final bytes = has ? _goshuinImages[slot] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _openGoshuinViewer(slot),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD0B48A)),
              color: Colors.white,
            ),
            child: bytes == null
                ? const Center(
                    child: Icon(Icons.image_outlined, color: Colors.black38),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(bytes, fit: BoxFit.cover),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              tooltip: '選ぶ',
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              onPressed: () => _setGoshuinFromGallery(slot),
            ),
            IconButton(
              tooltip: '撮る',
              icon: const Icon(Icons.photo_camera_outlined, size: 20),
              onPressed: () => _setGoshuinFromCamera(slot),
            ),
            if (has)
              IconButton(
                tooltip: '削除',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _clearGoshuin(slot),
              ),
          ],
        ),
      ],
    );
  }

  // ---------- アルバム：複数追加 ----------
  Future<void> _pickImages() async {
    try {
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

      final ok = await _saveNowVerified(verifyGoshuin: false);
      if (!ok) _snack('画像は表示できましたが、保存確認に失敗しました');
    } catch (e) {
      debugPrint('アルバム 追加エラー: $e');
      _snack('画像の読み込みに失敗しました');
    }
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

    final okDialog = await showDialog<bool>(
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

    if (okDialog != true) return;

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

    final ok = await _saveNowVerified(verifyGoshuin: false);
    if (!ok) _snack('削除は反映されましたが、保存確認に失敗しました');
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
                // 寺院プロフィール
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
                          onChanged: (_) => _saveNow(), // 静かに保存
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

                // 御朱印（2枠）
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '御朱印（最大2つ）',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                                child: _goshuinSlot(slot: 0, label: '御朱印①')),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _goshuinSlot(slot: 1, label: '御朱印②')),
                          ],
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

                // メモ
                TextField(
                  controller: _memoController,
                  maxLines: 4,
                  onChanged: (_) => _saveNow(),
                  decoration: const InputDecoration(labelText: '参拝メモ'),
                ),

                const SizedBox(height: 24),

                // アルバム（削除は追加ボタン横）
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
