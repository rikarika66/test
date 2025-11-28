import 'package:flutter/material.dart';
import 'book.dart'; // ← 修正：同一階層になったため

void main() {
  runApp(const GoshuinApp());
}

class GoshuinApp extends StatelessWidget {
  const GoshuinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'デジタル御朱印帳',
      debugShowCheckedModeBanner: false,
      home: TempleGoshuinPage(),
    );
  }
}

/// 寺院写真＋御朱印（表紙）
class TempleGoshuinPage extends StatelessWidget {
  const TempleGoshuinPage({super.key});

  final String templeImagePath = 'assets/images/hutuuji.png';
  final String goshuinImagePath = 'assets/images/hutuuji-gosyu.png';

  /// シンプルな右→左スライドで BookPage へ
  void _goToBookPage(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const BookPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0), // 画面の右端からスライド
              end: Offset.zero, // 中央へ
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('寺院と御朱印'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,

        // ▶ 右→左にスワイプしたときだけページ遷移
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            _goToBookPage(context);
          }
        },

        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景：寺院写真
            Image.asset(
              templeImagePath,
              fit: BoxFit.cover,
            ),

            // 背景を少し白くして見やすく
            Container(
              color: Colors.white.withOpacity(0.25),
            ),

            // 中央：御朱印画像（透過PNG）
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

            // 右下に今日の日付
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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

/// 今日の日付を「YYYY年M月D日」形式で返す
String _todayString() {
  final now = DateTime.now();
  return "${now.year}年${now.month}月${now.day}日";
}
