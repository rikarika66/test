import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image/image.dart' as img;

import 'temple_store.dart';
import 'image_storage.dart'; // ★追加：ファイル保存ヘルパー
import 'pages/cover.dart';
import 'pages/qr_scan.dart';

class BookPage extends StatefulWidget {
  const BookPage({
    super.key,
    required this.templeId,
    this.templeIds,
    this.currentIndex,
    this.initialQrUrl,
  });

  final String templeId;
  final List<String>? templeIds;
  final int? currentIndex;
  final String? initialQrUrl;

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

  final _memoFocusNode = FocusNode();
  final _scrollController = ScrollController();
  TempleEntry? _entry;

  // アルバム（★パス運用）
  final List<String> _albumPaths = [];
  bool _albumSelectionMode = false;
  final Set<int> _albumSelectedIndexes = <int>{};

  // 御朱印（★パス運用・最大2枚）
  final List<String> _goshuinPaths = [];
  int? _goshuinTrashSlot;

  DateTime? _visitDate;
  final _picker = ImagePicker();

  // ================================
  // 保存前に画像を軽量化（bytes→bytes）
  // ================================
  Uint8List _compressForStorage(
    Uint8List src, {
    int maxWidth = 1400,
    int quality = 82,
  }) {
    if (src.lengthInBytes < 250 * 1024) return src;

    try {
      final decoded = img.decodeImage(src);
      if (decoded == null) return src;

      final resized = (decoded.width > maxWidth)
          ? img.copyResize(decoded, width: maxWidth)
          : decoded;

      final jpg = img.encodeJpg(resized, quality: quality);
      return Uint8List.fromList(jpg);
    } catch (_) {
      return src;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEntry();

    final url = widget.initialQrUrl?.trim();
    if (url != null && url.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _setGoshuinFromQrUrl(0, url);
        await _afterQrImported();
      });
    }
  }

  @override
  void dispose() {
    _templeNameController.dispose();
    _visitDateController.dispose();
    _memoController.dispose();
    _addressController.dispose();
    _sectController.dispose();
    _honzonController.dispose();

    _memoFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadEntry() async {
    final loaded = await TempleStore.loadById(widget.templeId);
    final entry = loaded ?? TempleStore.newEntryWithId(widget.templeId);
    _entry = entry;

    if (loaded == null) {
      await TempleStore.upsert(entry);
    }

    _templeNameController.text = entry.templeName;
    _visitDateController.text = entry.visitDateText;
    _memoController.text = entry.memo;

    _addressController.text = entry.address;
    _sectController.text = entry.sect;
    _honzonController.text = entry.honzon;

    _visitDate = _parseDate(entry.visitDateText);

    _albumPaths
      ..clear()
      ..addAll(entry.albumImagePaths);

    _goshuinPaths
      ..clear()
      ..addAll(entry.goshuinImagePaths.take(2));

    if (mounted) setState(() {});
  }

  Future<void> _saveNow() async {
    final e = _entry;
    if (e == null) return;

    // スナップショット（テキストだけでOK：画像はパス運用なので軽い）
    final prevTempleName = e.templeName;
    final prevVisitDateText = e.visitDateText;
    final prevMemo = e.memo;

    final prevAddress = e.address;
    final prevSect = e.sect;
    final prevHonzon = e.honzon;

    final prevAlbum = List<String>.from(e.albumImagePaths);
    final prevGoshuin = List<String>.from(e.goshuinImagePaths);

    // 反映
    e.templeName = _templeNameController.text;
    e.visitDateText = _visitDateController.text;
    e.memo = _memoController.text;

    e.address = _addressController.text;
    e.sect = _sectController.text;
    e.honzon = _honzonController.text;

    e.albumImagePaths = List<String>.from(_albumPaths);
    e.goshuinImagePaths = List<String>.from(_goshuinPaths.take(2));
    e.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;

    final ok = await TempleStore.upsert(e);
    if (!ok) {
      // 戻す
      e.templeName = prevTempleName;
      e.visitDateText = prevVisitDateText;
      e.memo = prevMemo;

      e.address = prevAddress;
      e.sect = prevSect;
      e.honzon = prevHonzon;

      e.albumImagePaths = prevAlbum;
      e.goshuinImagePaths = prevGoshuin;

      if (mounted) {
        _snack('保存できませんでした（ストレージ制限の可能性）。');
      }
    }
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

      final nowList = _goshuinPaths.where((p) => p.trim().isNotEmpty).toList();
      final savedList =
          reloaded.goshuinImagePaths.where((p) => p.trim().isNotEmpty).toList();

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
  bool get _blockPaging => _albumSelectionMode || _goshuinTrashSlot != null;

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
    FocusScope.of(context).unfocus();

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

  Future<void> _setToday() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    _visitDate = DateTime(now.year, now.month, now.day);
    _visitDateController.text = _formatDate(_visitDate!);

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

  // ---------- 御朱印：スロット操作（パス） ----------
  String _getSlotPath(int slot) {
    if (slot < 0) return '';
    if (slot >= _goshuinPaths.length) return '';
    return _goshuinPaths[slot];
  }

  void _setSlotPath(int slot, String path) {
    while (_goshuinPaths.length <= slot) {
      _goshuinPaths.add('');
    }
    _goshuinPaths[slot] = path;

    while (_goshuinPaths.isNotEmpty && _goshuinPaths.last.trim().isEmpty) {
      _goshuinPaths.removeLast();
    }
    if (_goshuinPaths.length > 2) {
      _goshuinPaths.removeRange(2, _goshuinPaths.length);
    }
  }

  Future<void> _setGoshuinFromGallery(int slot) async {
    if (kIsWeb) {
      _snack('Webではファイル保存が使えません（スマホアプリでご利用ください）。');
      return;
    }
    final e = _entry;
    if (e == null) return;

    try {
      final x = await _picker.pickImage(source: ImageSource.gallery);
      if (x == null) return;

      // できるだけパスコピー（高速）
      final copied = await ImageStorage.copyFromPath(
        entryId: e.id,
        sourcePath: x.path,
        kind: 'goshuin',
      );

      if (copied.isEmpty) {
        // 念のためbytes保存にフォールバック
        final bytes = _compressForStorage(await x.readAsBytes());
        final saved = await ImageStorage.saveBytes(
          entryId: e.id,
          bytes: bytes,
          kind: 'goshuin',
          ext: 'jpg',
        );
        setState(() => _setSlotPath(slot, saved));
      } else {
        setState(() => _setSlotPath(slot, copied));
      }
    } catch (e) {
      debugPrint('御朱印（ギャラリー）読み込みエラー: $e');
      _snack('画像の読み込みに失敗しました');
      return;
    }

    final ok = await _saveNowVerified(verifyGoshuin: true);
    if (!ok) _snack('画像は表示できましたが、保存確認に失敗しました');
  }

  Future<void> _setGoshuinFromCamera(int slot) async {
    if (kIsWeb) {
      _snack('Webではファイル保存が使えません（スマホアプリでご利用ください）。');
      return;
    }
    final e = _entry;
    if (e == null) return;

    try {
      final x = await _picker.pickImage(source: ImageSource.camera);
      if (x == null) return;

      final bytes = _compressForStorage(await x.readAsBytes());
      final saved = await ImageStorage.saveBytes(
        entryId: e.id,
        bytes: bytes,
        kind: 'goshuin',
        ext: 'jpg',
      );
      setState(() => _setSlotPath(slot, saved));
    } catch (e) {
      debugPrint('御朱印（カメラ）読み込みエラー: $e');
      _snack('画像の読み込みに失敗しました');
      return;
    }

    final ok = await _saveNowVerified(verifyGoshuin: true);
    if (!ok) _snack('画像は表示できましたが、保存確認に失敗しました');
  }

  Future<void> _setGoshuinFromQr(int slot) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );

    if (!mounted) return;
    if (code == null || code.trim().isEmpty) return;

    await _setGoshuinFromQrUrl(slot, code.trim());
    await _afterQrImported();
  }

  Future<void> _setGoshuinFromQrUrl(int slot, String text) async {
    Uri? uri;
    try {
      uri = Uri.parse(text.trim());
    } catch (_) {
      uri = null;
    }

    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      _snack('QRの内容がURLではありませんでした');
      return;
    }

    final path = uri.path.toLowerCase();
    final looksJson = path.endsWith('.json');
    final looksImage = path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.webp');

    try {
      if (looksJson || !looksImage) {
        final res = await http.get(uri);
        if (res.statusCode != 200) {
          _snack('情報取得に失敗しました（${res.statusCode}）');
          return;
        }

        final body = utf8.decode(res.bodyBytes, allowMalformed: true).trim();
        if (body.startsWith('{')) {
          final obj = jsonDecode(body) as Map<String, dynamic>;

          _applyTempleInfoFromJson(obj);

          final imageUrl = _extractImageUrl(obj);
          if (imageUrl == null || imageUrl.isEmpty) {
            _snack('JSONに画像URLが見つかりませんでした');
            return;
          }

          await _downloadAndSetImage(slot, Uri.parse(imageUrl));
          return;
        }
      }

      await _downloadAndSetImage(slot, uri);
      return;
    } catch (e) {
      if (kIsWeb) {
        _snack(
            'このURLはブラウザ制限(CORS)で取得できない可能性があります。URLを開いて画像を保存し、「写真ライブラリ」から追加してください。');
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
        return;
      }
      debugPrint('御朱印（QR）取得エラー: $e');
      _snack('取得中にエラーが発生しました');
    }
  }

  Future<void> _afterQrImported() async {
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    final visitEmpty = _visitDateController.text.trim().isEmpty;

    if (visitEmpty) {
      _pickDate();
      return;
    }

    try {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } catch (_) {}

    if (!mounted) return;
    FocusScope.of(context).requestFocus(_memoFocusNode);
  }

  String? _extractImageUrl(Map<String, dynamic> obj) {
    final goshuin = obj['goshuin'];
    if (goshuin is Map<String, dynamic>) {
      final u = goshuin['imageUrl'];
      if (u is String && u.trim().isNotEmpty) return u.trim();
    }
    final u2 = obj['imageUrl'];
    if (u2 is String && u2.trim().isNotEmpty) return u2.trim();
    return null;
  }

  void _applyTempleInfoFromJson(Map<String, dynamic> obj) {
    final temple = obj['temple'];
    if (temple is Map<String, dynamic>) {
      if (temple['name'] is String) _templeNameController.text = temple['name'];
      if (temple['address'] is String) {
        _addressController.text = temple['address'];
      }
      if (temple['sect'] is String) _sectController.text = temple['sect'];
      if (temple['honzon'] is String) _honzonController.text = temple['honzon'];
    }
    setState(() {});
  }

  Future<void> _downloadAndSetImage(int slot, Uri uri) async {
    if (kIsWeb) {
      _snack('Webではファイル保存が使えません（スマホアプリでご利用ください）。');
      return;
    }
    final e = _entry;
    if (e == null) return;

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      _snack('画像取得に失敗しました（${res.statusCode}）');
      return;
    }

    final bytes = res.bodyBytes;
    if (bytes.isEmpty) {
      _snack('画像データが空でした');
      return;
    }

    // ★QR取得画像も保存前に軽量化してからファイル化
    final compressed = _compressForStorage(bytes);
    final saved = await ImageStorage.saveBytes(
      entryId: e.id,
      bytes: compressed,
      kind: 'goshuin',
      ext: 'jpg',
    );

    setState(() {
      _setSlotPath(slot, saved);
      _goshuinTrashSlot = null;
    });

    final ok = await _saveNowVerified(verifyGoshuin: true);
    if (!ok) {
      _snack('画像は表示できましたが、保存確認に失敗しました');
    } else {
      _snack('QRから御朱印を取り込みました');
    }
  }

  void _openGoshuinViewer(int slot) {
    final path = _getSlotPath(slot);
    if (path.trim().isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SingleImageViewer(path: path, title: '御朱印'),
      ),
    );
  }

  Future<void> _chooseGoshuinSource(int slot) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('写真ライブラリ'),
                enableFeedback: false,
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('カメラ'),
                enableFeedback: false,
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('QRコード'),
                enableFeedback: false,
                onTap: () => Navigator.pop(context, 'qr'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == 'gallery') {
      await _setGoshuinFromGallery(slot);
    } else if (result == 'camera') {
      await _setGoshuinFromCamera(slot);
    } else if (result == 'qr') {
      await _setGoshuinFromQr(slot);
    }
  }

  // ---------- 御朱印：長押しで🗑️表示 ----------
  void _showGoshuinTrash(int slot) {
    final has = _getSlotPath(slot).trim().isNotEmpty;
    if (!has) return;
    setState(() => _goshuinTrashSlot = slot);
  }

  void _hideGoshuinTrash() {
    if (_goshuinTrashSlot == null) return;
    setState(() => _goshuinTrashSlot = null);
  }

  Future<void> _deleteGoshuinSlot(int slot) async {
    final path = _getSlotPath(slot);
    if (path.trim().isEmpty) return;

    final okDialog = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('この御朱印を削除します。'),
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

    // ★ファイルも削除
    await ImageStorage.deleteFile(path);

    setState(() {
      if (slot >= 0 && slot < _goshuinPaths.length) {
        _goshuinPaths[slot] = '';
      }
      while (_goshuinPaths.isNotEmpty && _goshuinPaths.last.trim().isEmpty) {
        _goshuinPaths.removeLast();
      }
      _goshuinTrashSlot = null;
    });

    final ok = await _saveNowVerified(verifyGoshuin: true);
    if (!ok) _snack('削除は反映されましたが、保存確認に失敗しました');
  }

  Widget _goshuinSlot({required int slot, required String label}) {
    final path = _getSlotPath(slot);
    final has = path.trim().isNotEmpty;
    final showTrash = _goshuinTrashSlot == slot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 6),
        GestureDetector(
          onLongPress: has ? () => _showGoshuinTrash(slot) : null,
          onTap: () async {
            if (_goshuinTrashSlot != null) {
              _hideGoshuinTrash();
              return;
            }
            if (has) {
              _openGoshuinViewer(slot);
            } else {
              await _chooseGoshuinSource(slot);
            }
          },
          child: Stack(
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD0B48A)),
                  color: Colors.white,
                ),
                child: has
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.add_photo_alternate_outlined,
                            color: Colors.black38),
                      ),
              ),
              if (showTrash)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (showTrash)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Material(
                    color: Colors.red.withOpacity(0.95),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _deleteGoshuinSlot(slot),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child:
                            Icon(Icons.delete, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- アルバム：複数追加（パス保存） ----------
  Future<void> _pickImages() async {
    if (kIsWeb) {
      _snack('Webではファイル保存が使えません（スマホアプリでご利用ください）。');
      return;
    }
    final e = _entry;
    if (e == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: false, // ★スマホはパスコピーでOK
      );
      if (result == null || result.files.isEmpty) return;

      final added = <String>[];
      for (final f in result.files) {
        final pth = f.path;
        if (pth == null || pth.trim().isEmpty) continue;

        final copied = await ImageStorage.copyFromPath(
          entryId: e.id,
          sourcePath: pth,
          kind: 'album',
        );
        if (copied.isNotEmpty) added.add(copied);
      }
      if (added.isEmpty) return;

      setState(() {
        _albumPaths.addAll(added);
      });

      final ok = await _saveNowVerified(verifyGoshuin: false);
      if (!ok) _snack('画像は表示できましたが、保存確認に失敗しました');
    } catch (e) {
      debugPrint('アルバム 追加エラー: $e');
      _snack('画像の読み込みに失敗しました');
    }
  }

  // ---------- アルバム：選択モード ----------
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

    final sorted = _albumSelectedIndexes.toList()
      ..sort((a, b) => b.compareTo(a));

    // ★ファイルも削除してからリストから消す
    for (final i in sorted) {
      if (i >= 0 && i < _albumPaths.length) {
        final path = _albumPaths[i];
        await ImageStorage.deleteFile(path);
      }
    }

    setState(() {
      for (final i in sorted) {
        if (i >= 0 && i < _albumPaths.length) {
          _albumPaths.removeAt(i);
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
        builder: (_) => _ImageViewer(paths: _albumPaths, index: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final edge = MediaQuery.of(context).size.width * 0.10;

    final baseTitle = _templeNameController.text.isEmpty
        ? '御朱印帳'
        : '御朱印帳（${_templeNameController.text}）';

    final commonInputDecoration = const InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(baseTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: '共有',
            icon: const Icon(Icons.share),
            onPressed: _share,
          ),
          IconButton(
            tooltip: 'トップへ',
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const CoverPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (_goshuinTrashSlot != null &&
                  (n is ScrollStartNotification ||
                      n is UserScrollNotification ||
                      n is ScrollUpdateNotification)) {
                _hideGoshuinTrash();
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 御朱印
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '御朱印（最大2つ）',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
                            'タップ：追加/拡大　長押し：🗑️表示',
                            style:
                                TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 寺院プロフィール
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: _pickDate,
                            child: AbsorbPointer(
                              child: TextField(
                                controller: _visitDateController,
                                readOnly: true,
                                showCursor: false,
                                enableInteractiveSelection: false,
                                decoration: commonInputDecoration.copyWith(
                                  labelText: '参拝日',
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.calendar_today),
                                    onPressed: _setToday,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _templeNameController,
                            onChanged: (_) => _saveNow(),
                            decoration: commonInputDecoration.copyWith(
                              labelText: '寺院名',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _addressController,
                            onChanged: (_) => _saveNow(),
                            decoration: commonInputDecoration.copyWith(
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
                            decoration: commonInputDecoration.copyWith(
                              labelText: '宗派',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _honzonController,
                            onChanged: (_) => _saveNow(),
                            decoration: commonInputDecoration.copyWith(
                              labelText: '御本尊',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // メモ
                  TextField(
                    controller: _memoController,
                    focusNode: _memoFocusNode,
                    maxLines: 4,
                    onChanged: (_) => _saveNow(),
                    decoration: const InputDecoration(labelText: '参拝メモ'),
                  ),

                  const SizedBox(height: 24),

                  // アルバム
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '参拝アルバム',
                            style: TextStyle(fontSize: 16),
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

                  if (_albumPaths.isEmpty)
                    const Text('まだ写真がありません。右の「追加」から入れられます。')
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _albumPaths.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (_, i) {
                        final selected = _albumSelectedIndexes.contains(i);
                        final path = _albumPaths[i];

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
                                  border: Border.all(
                                      color: const Color(0xFFD0B48A)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.file(
                                    File(path),
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
  const _ImageViewer({required this.paths, required this.index});

  final List<String> paths;
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
        itemCount: paths.length,
        itemBuilder: (_, i) => Center(
          child: InteractiveViewer(
            child: Image.file(File(paths[i])),
          ),
        ),
      ),
    );
  }
}

class _SingleImageViewer extends StatelessWidget {
  const _SingleImageViewer({required this.path, required this.title});

  final String path;
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
          child: Image.file(File(path)),
        ),
      ),
    );
  }
}
