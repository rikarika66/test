import 'package:flutter/material.dart';

class CoverPage extends StatefulWidget {
  const CoverPage({super.key});

  @override
  State<CoverPage> createState() => _CoverPageState();
}

class _CoverPageState extends State<CoverPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 左からスッとスライド
    _slide = Tween<Offset>(
      begin: const Offset(-0.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    // ふわっとフェードイン
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    // ★ 表紙が出てから 2 秒後にボタンアニメーション開始
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 共通のメニューボタン
  Widget _menuButton(
    String label,
    VoidCallback onPressed,
    double width,
  ) {
    return SizedBox(
      width: width,
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // 角丸
          ),
        ),
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown, // 幅20%でも文字が収まるように
          child: Text(label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenSize = media.size;
    final usableHeight = screenSize.height - media.padding.vertical;
    final buttonWidth = screenSize.width * 0.20; // 画面横幅の20%

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 中央に表紙画像：縦いっぱいに縮小して表示（トリミングなし）
            Center(
              child: SizedBox(
                height: usableHeight,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Image.asset(
                    'assets/images/top2.png', // ← 表紙画像
                  ),
                ),
              ),
            ),

            // 画面下に4つのボタン（2秒後に同時にふわっと左から）
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _menuButton(
                          '御朱印帳',
                          () => Navigator.pushNamed(context, '/book'),
                          buttonWidth,
                        ),
                        _menuButton(
                          'ユーザー',
                          () => Navigator.pushNamed(context, '/user'),
                          buttonWidth,
                        ),
                        _menuButton(
                          '表紙設定',
                          () => Navigator.pushNamed(context, '/cover-set'),
                          buttonWidth,
                        ),
                        _menuButton(
                          'SNS',
                          () => Navigator.pushNamed(context, '/sns'),
                          buttonWidth,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
