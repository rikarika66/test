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
  // ★ 最後に表示していた季節を保持（重要）
  static int lastSeasonIndex = 0;

  // ===== 表紙（季節）=====
  final List<_SeasonCover> _covers = const [
    _SeasonCover(label: '春', assetPath: 'assets/images/cs.png', icon: '🌸'),
    _SeasonCover(label: '夏', assetPath: 'assets/images/cu.png', icon: '☀️'),
    _SeasonCover(label: '秋', assetPath: 'assets/images/ca.png', icon: '🍁'),
    _SeasonCover(label: '冬', assetPath: 'assets/images/cw.png', icon: '❄️'),
  ];

  late int _index;

  // ===== 下ボタンのタップ範囲調整 =====
  static const double _tapWidthFactor = 0.86;
  static const double _tapShiftX = -0.12;
  static const double _bottomAreaHeight = 96;
  static const EdgeInsets _bottomPadding = EdgeInsets.fromLTRB(24, 0, 24, 20);

  @override
  void initState() {
    super.initState();
    // ★ 前回の季節を復元
    _index = lastSeasonIndex.clamp(0, _covers.length - 1);
  }

  void _nextCover() {
    setState(() {
      _index = (_index + 1) % _covers.length;
      lastSeasonIndex = _index; // ★保存
    });
  }

  void _setCover(int i) {
    setState(() {
      _index = i;
      lastSeasonIndex = i; // ★保存
    });
  }

  @override
  Widget build(BuildContext context) {
    final cover = _covers[_index];

    return Scaffold(
      body: Stack(
        children: [
          // ===== 表紙（1枚だけ、100%表示）=====
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
                  ],
                ),
              ),
            ),
          ),

          // ===== 下ボタン（タップ範囲のみ）=====
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
        color: Colors.black.withOpacity(0.22),
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

// ===== 透明タップエリア =====
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
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Semantics(
          button: true,
          label: label,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
