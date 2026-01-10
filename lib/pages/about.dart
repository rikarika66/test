import 'package:flutter/material.dart';
import 'cover.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CoverPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('このアプリについて'),
        automaticallyImplyLeading: false, // 左上の戻る矢印を出さない
        actions: [
          IconButton(
            tooltip: 'トップへ',
            icon: const Icon(Icons.home),
            onPressed: () => _goHome(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'デジタル御朱印帳',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '参拝の記録（寺院情報）と、御朱印（最大2つ）を保存できるアプリです。\n'
                    '表紙（春・夏など）は今後も追加予定です。',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '使い方',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('・寺院一覧：寺院ページの追加／一覧表示'),
                  Text('・きろく：御朱印（参拝アルバム）の追加／削除'),
                  Text('・参拝日：日付欄タップで選択、カレンダーアイコンで今日に設定'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'メモ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('・データは端末内に保存されます。'),
                  Text('・バックアップや共有機能は今後追加予定です。'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '© Digital Goshuin Book',
              style: TextStyle(color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }
}
