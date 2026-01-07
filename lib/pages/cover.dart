import 'package:flutter/material.dart';

import '../temple_list.dart';
import '../book.dart';
import '../temple_store.dart';
import 'about.dart';

class CoverPage extends StatelessWidget {
  const CoverPage({super.key});

  // 背景画像（あなたのassetsに合わせて変更OK）
  final String _backgroundPath = 'assets/images/hutuuji.png';

  // 表紙中央に見せたい画像（無いならファイル名を空にしてもOK）
  final String _centerImagePath = 'assets/images/hutuuji-gosyu.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景
          Image.asset(_backgroundPath, fit: BoxFit.cover),

          // 文字・ボタンを見やすくする薄暗いレイヤー
          Container(color: Colors.black.withOpacity(0.25)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 6),

                  // 表紙内タイトル（※他画面側のタイトル/ボタンは不要）
                  const Text(
                    'デジタル御朱印帳',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(blurRadius: 6, color: Colors.black54),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 中央エリア（画像が無くても落ちない）
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(color: Colors.black.withOpacity(0.12)),

                              // 画像が無い/読み込めない場合でもクラッシュしない
                              if (_centerImagePath.trim().isNotEmpty)
                                Image.asset(
                                  _centerImagePath,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),

                              // 日付表示
                              Positioned(
                                right: 10,
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.40),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _todayString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3ボタン（左→右）
                  Row(
                    children: [
                      Expanded(
                        child: _CoverButton(
                          label: '寺院リスト',
                          icon: Icons.temple_buddhist,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TempleListPage(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CoverButton(
                          label: 'きろく',
                          icon: Icons.book,
                          onTap: () async {
                            // ★BookPage は templeId 必須なので、最新寺院を開く
                            final entries = await TempleStore.loadAll();

                            if (!context.mounted) return;

                            if (entries.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('まだ寺院の記録がありません。先に寺院を追加してください。'),
                                ),
                              );
                              return;
                            }

                            // 先頭＝最新（TempleStoreの実装が日付降順なら最新）
                            final ids = entries.map((e) => e.id).toList();
                            final first = entries.first;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookPage(
                                  templeId: first.id,
                                  templeIds: ids,
                                  currentIndex: 0,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CoverButton(
                          label: 'このアプリについて',
                          icon: Icons.info_outline,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AboutPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CoverButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.90),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: Colors.black87),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _todayString() {
  final now = DateTime.now();
  return "${now.year}年${now.month}月${now.day}日";
}
