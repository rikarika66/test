import 'dart:typed_data';
import 'dart:ui'; // ImageFilter（ぼかし）用

import 'package:flutter/material.dart';

import 'temple_store.dart';
import 'book.dart';

enum TempleSortMode {
  visitDateDesc,
  visitDateAsc,
  nameAsc,
}

class TempleListPage extends StatefulWidget {
  const TempleListPage({super.key});

  @override
  State<TempleListPage> createState() => _TempleListPageState();
}

class _TempleListPageState extends State<TempleListPage> {
  List<TempleEntry> _entries = [];
  TempleSortMode _sortMode = TempleSortMode.visitDateDesc;

  // 長押しで🗑️を出す（表示中タイルID）
  String? _trashTempleId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

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

  int _compareDateNullable(DateTime? a, DateTime? b, {required bool desc}) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    final cmp = a.compareTo(b);
    return desc ? -cmp : cmp;
  }

  void _applySort(List<TempleEntry> list) {
    switch (_sortMode) {
      case TempleSortMode.visitDateDesc:
        list.sort((x, y) => _compareDateNullable(
              _parseDate(x.visitDateText),
              _parseDate(y.visitDateText),
              desc: true,
            ));
        break;
      case TempleSortMode.visitDateAsc:
        list.sort((x, y) => _compareDateNullable(
              _parseDate(x.visitDateText),
              _parseDate(y.visitDateText),
              desc: false,
            ));
        break;
      case TempleSortMode.nameAsc:
        list.sort((x, y) => (x.templeName).compareTo(y.templeName));
        break;
    }
  }

  Future<void> _reload() async {
    final all = await TempleStore.loadAll();
    _applySort(all);
    if (!mounted) return;
    setState(() => _entries = all);
  }

  Future<void> _pushSlide(Widget page) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
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

  List<String> _currentTempleIds() => _entries.map((e) => e.id).toList();

  Future<void> _addNew() async {
    final entry = TempleStore.newEntry();

    setState(() {
      _entries.insert(0, entry);
    });

    await TempleStore.upsert(entry);
    if (!mounted) return;

    final ids = _currentTempleIds();
    final idx = ids.indexOf(entry.id);

    await _pushSlide(
      BookPage(
        templeId: entry.id,
        templeIds: ids,
        currentIndex: idx,
      ),
    );

    await _reload();
  }

  Future<void> _open(String id) async {
    final ids = _currentTempleIds();
    final idx = ids.indexOf(id);

    await _pushSlide(
      BookPage(
        templeId: id,
        templeIds: ids,
        currentIndex: idx,
      ),
    );
    await _reload();
  }

  void _showTrash(String id) {
    setState(() => _trashTempleId = id);
  }

  void _hideTrash() {
    if (_trashTempleId == null) return;
    setState(() => _trashTempleId = null);
  }

  Future<void> _delete(String id, String templeName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('「$templeName」のページを削除します。'),
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

    if (ok == true) {
      await TempleStore.deleteById(id);
      _hideTrash();
      await _reload();
    }
  }

  String _sortLabel(TempleSortMode m) {
    switch (m) {
      case TempleSortMode.visitDateDesc:
        return '参拝日：新しい順';
      case TempleSortMode.visitDateAsc:
        return '参拝日：古い順';
      case TempleSortMode.nameAsc:
        return '寺院名：A→Z';
    }
  }

  /// 御朱印サムネ：①があれば①、なければ②、どちらも空ならnull
  Uint8List? _pickGoshuinThumbBytes(TempleEntry e) {
    for (final b in e.goshuinImages) {
      if (b.isNotEmpty) return b;
    }
    return null;
  }

  // 文字影（B）
  List<Shadow> get _textShadows => const [
        Shadow(
          blurRadius: 3,
          offset: Offset(0, 1.5),
          color: Colors.black87,
        ),
      ];

  Widget _gridTile(TempleEntry e) {
    final title = e.templeName.isEmpty ? '（寺院名未入力）' : e.templeName;
    final date = e.visitDateText.isEmpty ? '参拝日：未入力' : e.visitDateText;
    final bytes = _pickGoshuinThumbBytes(e);
    final showTrash = _trashTempleId == e.id;

    return GestureDetector(
      onLongPress: () => _showTrash(e.id),
      onTap: () {
        // 🗑️表示中は、まず閉じる（誤タップ防止）
        if (_trashTempleId != null) {
          _hideTrash();
          return;
        }
        _open(e.id);
      },
      child: Stack(
        children: [
          // 枠
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD0B48A)),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: bytes == null
                  ? Container(
                      color: Colors.white,
                      child: const Center(
                        child: Icon(Icons.image_outlined,
                            color: Colors.black38, size: 28),
                      ),
                    )
                  : Container(
                      // 御朱印は縦長が多いので "contain" で切れない表示
                      padding: const EdgeInsets.all(6),
                      color: Colors.white,
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
            ),
          ),

          // 下帯：C（ぼかし） + B（文字影） + 寺院名は2行
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.18),
                        width: 0.6,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2, // ★寺院名を2行まで
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          height: 1.10,
                          shadows: _textShadows,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                          height: 1.10,
                          shadows: _textShadows,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 🗑️表示中の薄暗さ
          if (showTrash)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

          // 🗑️（タイル右上）
          if (showTrash)
            Positioned(
              right: 6,
              top: 6,
              child: Material(
                color: Colors.red.withOpacity(0.95),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _delete(e.id, title),
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(Icons.delete, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 3列を基準
    const crossAxisCount = 3;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '表紙へ',
          icon: const Icon(Icons.home),
          onPressed: () {
            // 表紙から push で来ていれば pop で戻れる
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return;
            }
            // もしこの画面がホーム扱いでも、'/'へ戻して表紙へ
            Navigator.of(context).pushReplacementNamed('/');
          },
        ),
        title: Text('寺院一覧（${_sortLabel(_sortMode)}）'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<TempleSortMode>(
            tooltip: '並び替え',
            icon: const Icon(Icons.sort),
            initialValue: _sortMode,
            onSelected: (m) async {
              setState(() => _sortMode = m);
              await _reload();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: TempleSortMode.visitDateDesc,
                child: Text('参拝日：新しい順'),
              ),
              PopupMenuItem(
                value: TempleSortMode.visitDateAsc,
                child: Text('参拝日：古い順'),
              ),
              PopupMenuItem(
                value: TempleSortMode.nameAsc,
                child: Text('寺院名：A→Z'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
        icon: const Icon(Icons.add),
        label: const Text('寺院を追加'),
      ),
      body: _entries.isEmpty
          ? const Center(
              child: Text('まだ寺院ページがありません。\n右下の「寺院を追加」から作成できます。'),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                // スクロール開始で🗑️を閉じる（誤操作防止）
                if (_trashTempleId != null &&
                    (n is ScrollStartNotification ||
                        n is UserScrollNotification ||
                        n is ScrollUpdateNotification)) {
                  _hideTrash();
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _entries.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  // 御朱印っぽい縦長サムネ（帯が2行になったので少しだけ縦を稼ぐ）
                  childAspectRatio: 0.68,
                ),
                itemBuilder: (context, index) => _gridTile(_entries[index]),
              ),
            ),
    );
  }
}
