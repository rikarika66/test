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
  /// 将来、秋・冬を追加する前提で「配列」で持つ
  /// いまは 春(cs) / 夏(cu) だけ
  final List<_SeasonCover> _covers = const [
    _SeasonCover(label: '春', assetPath: 'assets/images/cs.png', icon: '🌸'),
    _SeasonCover(label: '夏', assetPath: 'assets/images/cu.png', icon: '☀️'),
    // 追加予定：
    // _SeasonCover(label: '秋', assetPath: 'assets/images/ca.png', icon: '🍁'),
    // _SeasonCover(label: '冬', assetPath: 'assets/images/cw.png', icon: '❄️'),
  ];

  int _index = 0; // 0=春, 1=夏...

  void _setCoverIndex(int newIndex) {
    setState(() => _index = newIndex);
  }

  void _nextCover() {
    setState(() => _index = (_index + 1) % _covers.length);
  }

  @override
  Widget build(BuildContext context) {
    final cover = _covers[_index];

    return Scaffold(
      body: Stack(
        children: [
          // ===== 表紙：季節の画像を「1枚だけ」全面表示 =====
          Positioned.fill(
            child: Image.asset(
              cover.assetPath,
              fit: BoxFit.cover,
            ),
          ),

          // ===== 切り替えUI（右上）=====
          // ・アイコンをタップで「次の季節へ」
          // ・長押し or メニューで直接選択も可能
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 直接選択できるメニュー
                    PopupMenuButton<int>(
                      tooltip: '表紙を選ぶ',
                      onSelected: _setCoverIndex,
                      itemBuilder: (_) => List.generate(_covers.length, (i) {
                        final c = _covers[i];
                        return PopupMenuItem<int>(
                          value: i,
                          child: Text('${c.icon}  ${c.label}'),
                        );
                      }),
                      child: _chip('${cover.icon} ${cover.label}'),
                    ),
                    const SizedBox(width: 8),
                    // 次へ（ワンタップ切替）
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

          // ===== ここが本題：下の3ボタンの「押せる範囲」だけを指定 =====
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                // あなたの下ボタンの位置に合わせて調整（まずはこれでOK）
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  height: 86, // ★あなたの下ボタンの高さに合わせて後で調整
                  child: Stack(
                    children: [
                      // ① 見た目（あなたの既存の下ボタンUI）をここに置く
                      // すでにcoverにあるなら、そのコードをこの中へ移してください。
                      const Positioned.fill(
                        child: _BottomButtonsVisualPlaceholder(),
                      ),

                      // ② 見た目の上に「透明タップ領域」を3分割で被せる（範囲指定）
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              child: _TapArea(
                                semanticsLabel: '寺院リスト',
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
                                semanticsLabel: 'きろく',
                                onTap: () async {
                                  // BookPageは templeId 必須 → 最新寺院を開く
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
                                semanticsLabel: 'このアプリについて',
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
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 季節表紙の定義（将来拡張しやすい）
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

/// 透明のタップ領域（見た目を変えずに“範囲だけ”指定する）
class _TapArea extends StatelessWidget {
  final String semanticsLabel;
  final VoidCallback onTap;

  const _TapArea({
    required this.semanticsLabel,
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
          label: semanticsLabel,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// ここは「あなたの下ボタンの見た目」を置く場所
/// いまはプレースホルダー。見た目を変えたくないので、あなたの既存UIに差し替えてください。
class _BottomButtonsVisualPlaceholder extends StatelessWidget {
  const _BottomButtonsVisualPlaceholder();

  @override
  Widget build(BuildContext context) {
    // 見た目は後であなたの既存ボタンに置き換える前提
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
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
