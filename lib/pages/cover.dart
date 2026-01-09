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
  // ===== 表紙（季節）=====
  final List<_SeasonCover> _covers = const [
    _SeasonCover(label: '春', assetPath: 'assets/images/cs.png', icon: '🌸'),
    _SeasonCover(label: '夏', assetPath: 'assets/images/cu.png', icon: '☀️'),
    // 将来追加例：
    // _SeasonCover(label: '秋', assetPath: 'assets/images/ca.png', icon: '🍁'),
    // _SeasonCover(label: '冬', assetPath: 'assets/images/cw.png', icon: '❄️'),
  ];

  int _index = 0;

  // ===== 下ボタンのタップ範囲調整 =====
  // ・widthFactor：タップ範囲全体の幅（3分割の土台）
  // ・tapShiftX：左右のずらし（-で左へ、+で右へ）
  // ・bottomAreaHeight：下エリアの高さ
  // ・bottomPadding：下エリアの余白
  //
  // いまの状況に合わせて “ここだけ” 調整すればOKです。
  static const double _tapWidthFactor = 0.86;
  static const double _tapShiftX = -0.08; // 左が内側 → もっと左なら -0.08 / 行き過ぎなら -0.04
  static const double _bottomAreaHeight = 96;
  static const EdgeInsets _bottomPadding = EdgeInsets.fromLTRB(24, 0, 24, 20);

  void _nextCover() {
    setState(() => _index = (_index + 1) % _covers.length);
  }

  void _setCover(int i) {
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final cover = _covers[_index];

    return Scaffold(
      body: Stack(
        children: [
          // ===== 表紙（cs/cu を1枚だけ、100%表示）=====
          Positioned.fill(
            child: Image.asset(
              cover.assetPath,
              fit: BoxFit.cover,
            ),
          ),

          // ===== 切替UI（右上）=====
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<int>(
                      tooltip: '表紙を選ぶ',
                      onSelected: _setCover,
                      itemBuilder: (_) => List.generate(_covers.length, (i) {
                        final c = _covers[i];
                        return PopupMenuItem<int>(
                          value: i,
                          child: Text('${c.icon} ${c.label}'),
                        );
                      }),
                      child: _chip('${cover.icon} ${cover.label}'),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _nextCover,
                      borderRadius: BorderRadius.circular(999),
                      child: _chip('切替'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===== 下ボタン（見た目は cs/cu に含まれているので、ここはタップ範囲だけ）=====
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: _bottomPadding,
                child: SizedBox(
                  height: _bottomAreaHeight,
                  child: Stack(
                    children: [
                      // 透明タップ範囲（3分割）
                      Positioned.fill(
                        child: Align(
                          alignment: const Alignment(_tapShiftX, 0),
                          child: FractionallySizedBox(
                            widthFactor: _tapWidthFactor,
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
                                            content: Text(
                                                'まだ寺院の記録がありません。先に寺院を追加してください。'),
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

                      // ※必要ならここに “デバッグ枠” を入れられます（普段は不要）
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
