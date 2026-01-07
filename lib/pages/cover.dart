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
  /// 季節表紙（将来：秋・冬を追加予定）
  final List<_SeasonCover> _covers = const [
    _SeasonCover(label: '春', assetPath: 'assets/images/cs.png', icon: '🌸'),
    _SeasonCover(label: '夏', assetPath: 'assets/images/cu.png', icon: '☀️'),
  ];

  int _index = 0;

  void _nextCover() {
    setState(() {
      _index = (_index + 1) % _covers.length;
    });
  }

  void _setCover(int index) {
    setState(() {
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cover = _covers[_index];

    return Scaffold(
      body: Stack(
        children: [
          // ================= 表紙画像（100%使用） =================
          Positioned.fill(
            child: Image.asset(
              cover.assetPath,
              fit: BoxFit.cover,
            ),
          ),

          // ================= 表紙切り替えUI =================
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Row(
                  children: [
                    PopupMenuButton<int>(
                      tooltip: '表紙を選ぶ',
                      onSelected: _setCover,
                      itemBuilder: (_) => List.generate(
                        _covers.length,
                        (i) => PopupMenuItem(
                          value: i,
                          child: Text('${_covers[i].icon} ${_covers[i].label}'),
                        ),
                      ),
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

          // ================= 下ボタンエリア =================
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  height: 90, // ★必要に応じて微調整
                  child: Stack(
                    children: [
                      // -------- 見た目（変更しない） --------
                      const Positioned.fill(
                        child: _BottomButtonsVisual(),
                      ),

                      // -------- タップ範囲（透明） --------
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              child: _TapArea(
                                label: '寺院リスト',
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
                              child: _TapArea(
                                label: 'きろく',
                                onTap: () async {
                                  final entries = await TempleStore.loadAll();
                                  if (!context.mounted) return;

                                  if (entries.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'まだ寺院の記録がありません。先に寺院を追加してください。'),
                                      ),
                                    );
                                    return;
                                  }

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

// ================= 季節表紙定義 =================
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

// ================= 下ボタンの見た目 =================
class _BottomButtonsVisual extends StatelessWidget {
  const _BottomButtonsVisual();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _card('寺院リスト')),
        const SizedBox(width: 10),
        Expanded(child: _card('きろく')),
        const SizedBox(width: 10),
        Expanded(child: _card('このアプリについて')),
      ],
    );
  }

  Widget _card(String text) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ================= 透明タップ領域 =================
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
