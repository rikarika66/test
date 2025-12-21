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
  bool _albumSelectionMode = false;
  final Set<int> _albumSelectedIndexes = <int>{};

  // 御朱印（最大2枚）
  final List<Uint8List> _goshuinImages = [];
  bool _goshuinSelectionMode = false;
  final Set<int> _goshuinSelectedSlots = <int>{};

  DateTime? _visitDate;
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

  Future<bool> _saveNowVerified({bool verifyGoshuin = true}) async {
    final e = _entry;
    if (e == null) return false;

    try {
      await _saveNow();
    } catch (err) {
      debugPrint('saveNow exception (but will verify): $err');
    }

    try {
      final reloaded = await TempleStore.loadById(e.id);
      if (reloaded == null) return false;

      if (!verifyGoshuin) return true;

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
  bool get _blockPaging => _albumSelectionMode || _goshuinSelectionMode;

  bool get _canGoPrev =>
      !_blockPaging &&
      widget.templeIds != null &&
      widget.currentIndex != null &&
      widget.currentIndex! > 0;

  bool get _canGoNext =>
      !_blockPaging &&
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

  // ---------- 御朱印：スロット ----------
  Uint8List _getSlot(int slot) {
    if (slot < 0) return Uint8List(0);
    if (slot >= _goshuinImages.length) return Uint8List(0);
    return _goshuinImages[slot];
  }

  bool _hasSlot(int slot) => _getSlot(slot).isNotEmpty;

  void _setSlotBytes(int slot, Uint8List bytes) {
    while (_goshuinImages.length <= slot) {
      _goshuinImages.add(Uint8List(0));
    }
    _goshuinImages[slot] = bytes;

    // 末尾の空を詰める
    while (_goshuinImages.isNotEmpty && _goshuinImages.last.isEmpty) {
      _goshuinImages.removeLast();
    }
    // 最大2枚
    if (_goshuinImages.length > 2) {
      _goshuinImages.removeRange(2, _goshuinImages.length);
    }
  }

  int? _nextEmptyGoshuinSlot() {
    if (!_hasSlot(0)) return 0;
    if (!_hasSlot(1)) return 1;
    return null;
  }

  Future<void> _chooseGoshuinSourceUnified() async {
    if (_goshuinSelectionMode) return;

    final slot = _nextEmptyGoshuinSlot();
    if (slot == null) {
      _snack('御朱印①②が埋まっています。入れ替える場合は長押しで削除してください。');
      return;
    }

    final result = await showModalBottomSheet<_PickChoice>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(slot == 0 ? 'アルバムから選ぶ（御朱印①へ）' : 'アルバムから選ぶ（御朱印②へ）'),
              onTap: () => Navigator.pop(context, _PickChoice.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(slot == 0 ? 'カメラで撮る（御朱印①へ）' : 'カメラで撮る（御朱印②へ）'),
              onTap: () => Navigator.pop(context, _PickChoice.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (result == null) return;

    final source = result == _PickChoice.gallery
        ? ImageSource.gallery
        : ImageSource.camera;
    await _setGoshuin(source: source, slot: slot);
  }

  Future<void> _setGoshuin(
      {required ImageSource source, required int slot}) async {
    try {
      final x = await _picker.pickImage(source: source);
      if (x == null) return;

      final bytes = await x.readAsBytes();
      setState(() => _setSlotBytes(slot, bytes));
    } catch (e) {
      debugPrint('御朱印 読み込みエラー: $e');
      _snack('画像の読み込みに失敗しました');
      return;
    }

    final ok = await _saveNowVerified(verifyGoshuin: true);
    if (!ok) _snack('画像は表示できましたが、保存確認に失敗しました');
  }

  void _openGoshuinViewer(int slot) {
    final bytes = _getSlot(slot);
    if (bytes.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SingleImageViewer(bytes: bytes, title: '御朱印'),
      ),
    );
  }

  // ---------- 御朱印：長押し削除 ----------
  void _enterGoshuinSelection(int slot) {
    if (!_hasSlot(slot)) return;
    setState(() {
      _goshuinSelectionMode = true;
      _goshuinSelectedSlots
        ..clear()
        ..add(slot);
    });
  }

  void _toggleGoshuinSelect(int slot) {
    if (!_hasSlot(slot)) return;
    setState(() {
      if (_goshuinSelectedSlots.contains(slot)) {
        _goshuinSelectedSlots.remove(slot);
      } else {
        _goshuinSelectedSlots.add(slot);
      }
      if (_goshuinSelectedSlots.isEmpty) {
        _goshuinSelectionMode = false;
      }
    });
  }

  void _exitGoshuinSelection() {
    setState(() {
      _goshuinSelectionMode = false;
      _goshuinSelectedSlots.clear();
    });
  }

  Future<void> _deleteSelectedGoshuin() async {
    if (_goshuinSelectedSlots.isEmpty) return;

    final okDialog = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('${_goshuinSelectedSlots.length}枚の御朱印を削除します。'),
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
      for (final slot in _goshuinSelectedSlots) {
        if (slot >= 0 && slot < _goshuinImages.length) {
          _goshuinImages[slot] = Uint8List(0);
        }
      }
      while (_goshuinImages.isNotEmpty && _goshuinImages.last.isEmpty) {
        _goshuinImages.removeLast();
      }
      _goshuinSelectedSlots.clear();
      _goshuinSelectionMode = false;
    });

    final ok = await _saveNowVerified(verifyGoshuin: true);
    if (!ok) _snack('削除は反映されましたが、保存確認に失敗しました');
  }

  // ★御朱印サムネ：見切れ対策（contain＋余白＋背景）
  Widget _goshuinThumb(int slot) {
    final bytes = _getSlot(slot);
    final has = bytes.isNotEmpty;
    final selected = _goshuinSelectedSlots.contains(slot);

    return GestureDetector(
      onLongPress: has ? () => _enterGoshuinSelection(slot) : null,
      onTap: () {
        if (_goshuinSelectionMode) {
          _toggleGoshuinSelect(slot);
        } else {
          _openGoshuinViewer(slot);
        }
      },
      child: Stack(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.all(6), // ★余白
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD0B48A)),
              color: Colors.white,
            ),
            child: has
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain, // ★切れない
                      alignment: Alignment.center,
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image_outlined, color: Colors.black38),
                  ),
          ),
          if (_goshuinSelectionMode)
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
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
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

      setState(() => _albumImages.addAll(picked));

      final ok = await _saveNowVerified(verifyGoshuin: false);
      if (!ok) _snack('画像は表示できましたが、保存確認に失敗しました');
    } catch (e) {
      debugPrint('アルバム 追加エラー: $e');
      _snack('画像の読み込みに失敗しました');
    }
  }

  void _enterAlbumSelectionMode(int index) {
    setState(() {
      _albumSelectionMode = true;
      _albumSelectedIndexes.add(index);
    });
  }

  void _toggleAlbumSelect(int index) {
    setState(() {
      if (_albumSelectedIndexes.contains(index)) {
        _albumSelectedIndexes.remove(index);
      } else {
        _albumSelectedIndexes.add(index);
      }
      if (_albumSelectedIndexes.isEmpty) {
        _albumSelectionMode = false;
      }
    });
  }

  void _exitAlbumSelectionMode() {
    setState(() {
      _albumSelectionMode = false;
      _albumSelectedIndexes.clear();
    });
  }

  Future<void> _deleteSelectedAlbumImages() async {
    if (_albumSelectedIndexes.isEmpty) return;

    final okDialog = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('${_albumSelectedIndexes.length}枚の写真を削除します。'),
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
      final sorted = _albumSelectedIndexes.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final i in sorted) {
        if (i >= 0 && i < _albumImages.length) {
          _albumImages.removeAt(i);
        }
      }
      _albumSelectedIndexes.clear();
      _albumSelectionMode = false;
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

                // 御朱印（追加ボタンは1つ）
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '御朱印（最大2つ）',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),

                            // ★追加ボタンは1つ（通常時のみ）
                            if (!_goshuinSelectionMode)
                              IconButton(
                                tooltip: '御朱印を追加',
                                icon: const Icon(
                                    Icons.add_photo_alternate_outlined),
                                onPressed: _chooseGoshuinSourceUnified,
                              ),

                            // ★選択モードの時は「解除/削除」だけ
                            if (_goshuinSelectionMode) ...[
                              IconButton(
                                tooltip: '選択解除',
                                icon: const Icon(Icons.close),
                                onPressed: _exitGoshuinSelection,
                              ),
                              IconButton(
                                tooltip: '削除',
                                icon: const Icon(Icons.delete),
                                onPressed: _goshuinSelectedSlots.isEmpty
                                    ? null
                                    : _deleteSelectedGoshuin,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text('御朱印①',
                                      style: TextStyle(
                                          color: Colors.black54, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  _goshuinThumb(0),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text('御朱印②',
                                      style: TextStyle(
                                          color: Colors.black54, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  _goshuinThumb(1),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'タップで拡大表示（削除は長押しで選択）',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                          textAlign: TextAlign.center,
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

                // アルバム（省略せず完全保持）
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
                        if (_albumSelectionMode) ...[
                          const SizedBox(width: 10),
                          Text(
                            '${_albumSelectedIndexes.length}枚選択',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        if (_albumSelectionMode) ...[
                          IconButton(
                            tooltip: '選択解除',
                            icon: const Icon(Icons.close),
                            onPressed: _exitAlbumSelectionMode,
                          ),
                          IconButton(
                            tooltip: '削除',
                            icon: const Icon(Icons.delete),
                            onPressed: _albumSelectedIndexes.isEmpty
                                ? null
                                : _deleteSelectedAlbumImages,
                          ),
                          const SizedBox(width: 6),
                        ],
                        ElevatedButton.icon(
                          onPressed: _albumSelectionMode ? null : _pickImages,
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
                      final selected = _albumSelectedIndexes.contains(i);

                      return GestureDetector(
                        onLongPress: () => _enterAlbumSelectionMode(i),
                        onTap: () {
                          if (_albumSelectionMode) {
                            _toggleAlbumSelect(i);
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
                            if (_albumSelectionMode)
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

enum _PickChoice { gallery, camera }

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
