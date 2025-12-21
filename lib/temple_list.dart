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

  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

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
      BookPage(templeId: entry.id, templeIds: ids, currentIndex: idx),
    );

    await _reload();
  }

  Future<void> _open(String id) async {
    final ids = _currentTempleIds();
    final idx = ids.indexOf(id);

    await _pushSlide(
      BookPage(templeId: id, templeIds: ids, currentIndex: idx),
    );

    await _reload();
  }

  // ---------- 選択モード ----------
  void _enterSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('${_selectedIds.length}件の寺院ページを削除します。'),
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

    for (final id in _selectedIds) {
      await TempleStore.deleteById(id);
    }

    _exitSelection();
    await _reload();
  }

  Widget _goshuinLeading(TempleEntry e) {
    final bytes = e.goshuinImages.isNotEmpty ? e.goshuinImages.first : null;

    return Container(
      width: 50,
      height: 66,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD0B48A)),
        color: Colors.white,
      ),
      child: bytes == null
          ? const Icon(Icons.image_outlined, color: Colors.black38)
          : ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _selectionMode
        ? '${_selectedIds.length}件選択'
        : '寺院一覧（${_sortLabel(_sortMode)}）';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: false,
        actions: _selectionMode
            ? [
                IconButton(
                  tooltip: '選択解除',
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelection,
                ),
                IconButton(
                  tooltip: '削除',
                  icon: const Icon(Icons.delete),
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                ),
              ]
            : [
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
        onPressed: _selectionMode ? null : _addNew,
        icon: const Icon(Icons.add),
        label: const Text('寺院を追加'),
      ),
      body: _entries.isEmpty
          ? const Center(
              child: Text('まだ寺院ページがありません。\n右下の「寺院を追加」から作成できます。'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final e = _entries[index];
                final selected = _selectedIds.contains(e.id);

                final title = e.templeName.isEmpty ? '（寺院名未入力）' : e.templeName;
                final sub = e.visitDateText.isEmpty
                    ? '参拝日：未入力'
                    : '参拝日：${e.visitDateText}';

                return GestureDetector(
                  onLongPress: () => _enterSelection(e.id),
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelection(e.id);
                    } else {
                      _open(e.id);
                    }
                  },
                  child: Stack(
                    children: [
                      Card(
                        child: ListTile(
                          leading: _goshuinLeading(e),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(sub),
                        ),
                      ),
                      if (_selectionMode)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.blue.withOpacity(0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      if (selected)
                        Positioned(
                          right: 14,
                          top: 12,
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
    );
  }
}
