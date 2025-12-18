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

  // ★ 追加：押した瞬間に一覧に反映 → 保存 → 詳細へ
  Future<void> _addNew() async {
    final entry = TempleStore.newEntry();

    // 先にUI反映（即見える）
    setState(() {
      _entries.insert(0, entry);
    });

    // 保存は後でOK
    await TempleStore.upsert(entry);
    if (!mounted) return;

    // 追加したらそのまま詳細へ
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookPage(templeId: entry.id)),
    );

    // 戻ってきたら確定データで再読込
    await _reload();
  }

  // ★ エラー原因だったメソッド：必ず必要
  Future<void> _open(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookPage(templeId: id)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('寺院一覧')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
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

                final title = e.templeName.isEmpty ? '（寺院名未入力）' : e.templeName;
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
    );
  }
}
