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

  final List<Uint8List> _albumImages = [];
  DateTime? _visitDate;
  TempleEntry? _entry;

  bool _selectionMode = false;
  final Set<int> _selectedIndexes = {};

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

    _albumImages
      ..clear()
      ..addAll(entry.albumImages);

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
    e.albumImages = List.from(_albumImages);

    await TempleStore.upsert(e);
  }

  // ---------- Kindle ページ移動 ----------
  bool get _canGoPrev =>
      widget.templeIds != null &&
      widget.currentIndex != null &&
      widget.currentIndex! > 0;

  bool get _canGoNext =>
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
    await _replace(widget.templeIds![i], i);
  }

  Future<void> _replace(String id, int index, {bool fromLeft = false}) async {
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => BookPage(
          templeId: id,
          templeIds: widget.templeIds,
          currentIndex: index,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final begin = fromLeft ? const Offset(-1, 0) : const Offset(1, 0);
          return SlideTransition(
            position: Tween(begin: begin, end: Offset.zero).animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  // ---------- 日付 ----------
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    _visitDateController.text = '${picked.year}年${picked.month}月${picked.day}日';
    await _saveNow();
    setState(() {});
  }

  // ---------- 地図 ----------
  Future<void> _openInMaps() async {
    final q = '${_templeNameController.text} ${_addressController.text}'.trim();
    if (q.isEmpty) return;

    await launchUrl(
      Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final edge = MediaQuery.of(context).size.width * 0.10;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _templeNameController.text.isEmpty
              ? '御朱印帳'
              : _templeNameController.text,
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share(_templeNameController.text);
            },
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
                TextField(
                  controller: _memoController,
                  maxLines: 4,
                  onChanged: (_) => _saveNow(),
                  decoration: const InputDecoration(labelText: '参拝メモ'),
                ),
              ],
            ),
          ),

          // 左：前の寺院
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

          // 右：次の寺院
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
