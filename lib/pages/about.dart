import 'package:flutter/material.dart';
import 'cover.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _appTitle = 'デジタル御朱印帳';
  static const String _appTagline = '御朱印と参拝の記録を、寺院ごとにまとめて残すアプリ';
  static const String _copyright = '© Digital Goshuin Book';

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CoverPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('このアプリについて'),
        automaticallyImplyLeading: false,
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
          // --- ヘッダー ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFF1E2A38),
                    child: Text('印', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _appTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _appTagline,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // --- まずはここから（最短ルート） ---
          const _SectionCard(
            title: 'まずはここから（最短ルート）',
            icon: Icons.play_circle_outline,
            children: [
              _Bullet('表紙の「寺院リスト」→ 右下の「寺院を追加」'),
              _Bullet('寺院ページで、御朱印①/②をタップして追加（写真 / カメラ / QR）'),
              _Bullet('参拝日・メモを入力すると、あとで見返しやすくなります'),
              _Bullet('一覧のタイルをタップすると、その寺院ページを開けます'),
            ],
          ),

          const SizedBox(height: 12),

          // --- できること ---
          const _SectionCard(
            title: 'できること',
            icon: Icons.auto_awesome,
            children: [
              _Bullet('寺院ごとにページを作成（寺院名・所在地・宗派・御本尊・メモ）'),
              _Bullet('御朱印は最大2つまで保存（御朱印① / 御朱印②）'),
              _Bullet('参拝アルバムに写真を複数保存（長押しで複数選択→削除）'),
              _Bullet('寺院一覧でサムネ表示、並び替え（参拝日 / 寺院名）'),
              _Bullet('QRから御朱印画像を取り込み（URLから取得）'),
            ],
          ),

          const SizedBox(height: 12),

          // --- 操作のヒント ---
          const _SectionCard(
            title: '操作のヒント',
            icon: Icons.tips_and_updates_outlined,
            children: [
              _Bullet('一覧：タイル長押しで🗑️表示（削除できます）'),
              _Bullet('御朱印：長押しで🗑️表示、タップで拡大表示'),
              _Bullet('参拝日：日付欄タップでカレンダー、アイコンで「今日」に設定'),
              _Bullet('「きろく」ボタンは、保存済み寺院の最初のページを開きます'),
            ],
          ),

          const SizedBox(height: 12),

          // --- データの保存について ---
          const _SectionCard(
            title: 'データの保存について',
            icon: Icons.lock_outline,
            children: [
              _Bullet('データは端末内に保存されます（クラウド送信は行いません）'),
              _Bullet('端末の機種変更や再インストールで消える可能性があります'),
              _Bullet('今後、バックアップ / 共有の仕組みを追加予定です'),
            ],
          ),

          const SizedBox(height: 12),

          // --- 今後の予定 ---
          const _SectionCard(
            title: '今後の予定',
            icon: Icons.route_outlined,
            children: [
              _Bullet('表紙デザインの追加（季節・寺社モチーフなど）'),
              _Bullet('バックアップ（エクスポート / インポート）'),
              _Bullet('共有（SNS向けの整形、画像共有など）'),
              _Bullet('検索・フィルタ（寺院名・参拝日など）'),
            ],
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              _copyright,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF1E2A38)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('・', style: TextStyle(height: 1.35)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
