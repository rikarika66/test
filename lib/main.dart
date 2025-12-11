import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'book.dart'; // ← lib/book.dart を読み込む

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

      // ★★★ ここが「日本語カレンダー」にするための設定 ★★★
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'), // 日本語（日本）
      ],
      // ★★★ ここまで ★★★

      home: const TempleGoshuinPage(),
    );
  }
}

/// 表紙ページ（Kindle方式：右タップで次へ）
class TempleGoshuinPage extends StatelessWidget {
  const TempleGoshuinPage({super.key});

  final String templeImagePath = 'assets/images/hutuuji.png';
  final String goshuinImagePath = 'assets/images/hutuuji-gosyu.png';

  /// 御朱印帳ページへ進む（スライドアニメ）
  void _goToBookPage(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const BookPage(),
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
          _goToBookPage(context);
        }
      },

      child: Scaffold(
        appBar: AppBar(
          title: const Text('寺院と御朱印'),
          automaticallyImplyLeading: false, // 戻るボタン消す
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ★ 寺院写真をそのまま表示（黒くしない・明るくしない）
            Image.asset(
              templeImagePath,
              fit: BoxFit.cover,
            ),

            // ★ 御朱印画像（影なし・フィルターなし）
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

            // ★ 日付
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
