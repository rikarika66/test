import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'temple_list.dart'; // ★ 寺院一覧ページへ

void main() {
  runApp(const GoshuinApp());
}

class GoshuinApp extends StatelessWidget {
  const GoshuinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'デジタル御朱印帳',
      debugShowCheckedModeBanner: false,

      // ★ 日本語カレンダー設定
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      // ★ ここまで

      home: const TempleGoshuinPage(),
    );
  }
}

/// 表紙ページ（Kindle方式：右タップで次へ）
class TempleGoshuinPage extends StatelessWidget {
  const TempleGoshuinPage({super.key});

  final String templeImagePath = 'assets/images/hutuuji.png';
  final String goshuinImagePath = 'assets/images/hutuuji-gosyu.png';

  /// 寺院一覧ページへ進む（スライドアニメ）
  void _goToTempleList(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const TempleListPage(),
        transitionsBuilder: (_, animation, __, child) {
          final offset = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          );
          return SlideTransition(position: offset, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      // ★ Kindle式：右半分タップでページ進む
      onTapUp: (TapUpDetails details) {
        final width = MediaQuery.of(context).size.width;
        if (details.localPosition.dx > width * 0.5) {
          _goToTempleList(context);
        }
      },

      child: Scaffold(
        appBar: AppBar(
          title: const Text('寺院と御朱印'),
          automaticallyImplyLeading: false,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              templeImagePath,
              fit: BoxFit.cover,
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Image.asset(
                    goshuinImagePath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _todayString(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _todayString() {
  final now = DateTime.now();
  return "${now.year}年${now.month}月${now.day}日";
}
