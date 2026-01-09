import 'package:flutter/material.dart';

import '../temple_list.dart';
import '../book.dart';
import '../temple_store.dart';
import 'about.dart';

class CoverPage extends StatefulWidget {
  const CoverPage({super.key});

  @override
  State<CoverPage> createState() => _CoverPageState();
}

class _CoverPageState extends State<CoverPage> {
  // 春/夏（将来：秋冬追加しやすい）
  final List<_SeasonCover> _covers = const [
    _SeasonCover(label: '春', assetPath: 'assets/images/cs.png', icon: '🌸'),
    _SeasonCover(label: '夏', assetPath: 'assets/images/cu.png', icon: '☀️'),
  ];

  int _index = 0;

  void _nextCover() {
    setState(() => _index = (_index + 1) % _covers.length);
  }

  @override
  Widget build(BuildContext context) {
    final cover = _covers[_index];

    return Scaffold(
      body: Stack(
        children: [
          // ===== 表紙（100%）=====
          Positioned.fill(
            child: Image.asset(
              cover.assetPath,
              fit: BoxFit.cover,
            ),
          ),

          // ===== 表紙切替（右上）=====
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: InkWell(
                  onTap: _nextCover,
                  borderRadius: BorderRadius.circular(999),
                  child: _chip('${cover.icon} ${cover.label}'),
                ),
              ),
            ),
          ),

          // ===== 下ボタンエリア（見た目画像＋タップ範囲）=====
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                // 位置調整（必要なら微調整）
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: SizedBox(
                  height: 96, // 必要なら微調整
                  child: Stack(
                    children: [
                      // --- 見た目：あなたのボタン画像（widthFactor:0.8） ---
                      const Positioned.fill(
                        child: _BottomButtonsImage(
                          widthFactor: 0.8,
                        ),
                      ),

                      // --- Aの本題：タップ範囲も同じwidthFactor(0.8)に揃える ---
                      Positioned.fill(
                        child: Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.8, // ★画像と同じ
                            child: Row(
                              children: [
                                Expanded(
                                  child: _TapArea(
                                    label: '寺院リスト',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const TempleListPage(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: _TapArea(
                                    label: 'きろく',
                                    onTap: () async {
                                      final entries =
                                          await TempleStore.loadAll();
                                      if (!context.mounted) return;

                                      if (entries.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('まだ寺院の記録がありません。'),
                                          ),
                                        );
                                        return;
                                      }

                                      final ids =
                                          entries.map((e) => e.id).toList();
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
                                Expanded(
                                  child: _TapArea(
                                    label: 'このアプリについて',
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ===== 季節表紙定義 =====
class _SeasonCover {
  final String label;
  final String assetPath;
  final String icon;
  const _SeasonCover({
    required this.label,
    required this.assetPath,
    required this.icon,
  });
}

// ===== 下ボタン（見た目：画像1枚）=====
// ここにあなたのボタン画像ファイル名を設定してください
class _BottomButtonsImage extends StatelessWidget {
  final double widthFactor;
  const _BottomButtonsImage({
    required this.widthFactor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: widthFactor, // 0.8
        child: Image.asset(
          'assets/images/bottom_buttons.png', // ★あなたの画像名に合わせて変更
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ===== 透明タップ範囲 =====
class _TapArea extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TapArea({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: label,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
