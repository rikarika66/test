import 'package:flutter/material.dart';

import 'temple_store.dart';
import 'book.dart';

class TempleListPage extends StatefulWidget {
  const TempleListPage({super.key});

  @override
  State<TempleListPage> createState() => _TempleListPageState();
}

class _TempleListPageState extends State<TempleListPage> {
  List<TempleEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final all = await TempleStore.loadAll();
    if (!mounted) return;
    setState(() => _entries = all);
  }

  // Kindle風：右→左スライドでpush
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

    // 先にUI反映（即見える）
    setState(() {
      _entries.insert(0, entry);
    });

    await TempleStore.upsert(entry);
    if (!mounted) return;

    // 追加したらそのまま詳細へ（右端“次”用に ids/index を渡す）
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
      await _reload();
    }
  }

  void _popIfPossible() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('寺院一覧'),
        automaticallyImplyLeading: false, // ←消す
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
        icon: const Icon(Icons.add),
        label: const Text('寺院を追加'),
      ),
      body: Stack(
        children: [
          _entries.isEmpty
              ? const Center(
                  child: Text('まだ寺院ページがありません。\n右下の「寺院を追加」から作成できます。'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final e = _entries[index];
                    final title =
                        e.templeName.isEmpty ? '（寺院名未入力）' : e.templeName;
                    final sub = e.visitDateText.isEmpty
                        ? '参拝日：未入力'
                        : '参拝日：${e.visitDateText}';

                    return Card(
                      child: ListTile(
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(sub),
                        onTap: () => _open(e.id),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(e.id, title),
                        ),
                      ),
                    );
                  },
                ),

          // Kindle操作：左端タップで戻る
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.18,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _popIfPossible,
            ),
          ),
        ],
      ),
    );
  }
}
