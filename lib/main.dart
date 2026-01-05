import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'temple_list.dart';
import 'temple_store.dart';
import 'book.dart';

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

      // 日本語ローカライズ
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],

      home: const CoverHomePage(),
    );
  }
}

/// ===============================
/// 表紙（ホーム）
class CoverHomePage extends StatefulWidget {
  const CoverHomePage({super.key});

  @override
  State<CoverHomePage> createState() => _CoverHomePageState();
}

class _CoverHomePageState extends State<CoverHomePage> {
  /// 月で表紙画像を切り替え
  String _pickCoverImage() {
    final month = DateTime.now().month;

    // 夏（6–8）
    if (month >= 6 && month <= 8) {
      return 'assets/images/cu.png';
    }

    // 春（3–5）
    if (month >= 3 && month <= 5) {
      return 'assets/images/cs.png';
    }

    // それ以外（暫定で春）
    return 'assets/images/cs.png';
  }

  Future<void> _pushSlide(Widget page) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => page,
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

  Future<void> _goTempleList() async {
    await _pushSlide(const TempleListPage());
  }

  Future<void> _goRecord() async {
    final entry = TempleStore.newEntry();
    await TempleStore.upsert(entry);

    final all = await TempleStore.loadAll();
    final ids = all.map((e) => e.id).toList();
    final idx = ids.indexOf(entry.id);

    await _pushSlide(
      BookPage(
        templeId: entry.id,
        templeIds: ids,
        currentIndex: idx >= 0 ? idx : 0,
      ),
    );
  }

  Future<void> _goAbout() async {
    await _pushSlide(const AboutPage());
  }

  @override
  Widget build(BuildContext context) {
    final coverPath = _pickCoverImage();
    const double buttonScale = 0.70;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ===== 表紙背景 =====
          Image.asset(
            coverPath,
            fit: BoxFit.cover,
          ),

          // ===== タイトル =====
          Positioned(
            top: MediaQuery.of(context).padding.top + 22,
            left: 0,
            right: 0,
            child: Column(
              children: const [
                Text(
                  'デジタル',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '御朱印帳',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // ===== メニューボタン =====
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Transform.scale(
              scale: buttonScale,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MenuButton(
                    icon: Icons.temple_buddhist,
                    label: '寺院一覧',
                    onTap: _goTempleList,
                  ),
                  _MenuButton(
                    icon: Icons.edit_note,
                    label: '御朱印を記録',
                    onTap: _goRecord,
                  ),
                  _MenuButton(
                    icon: Icons.info_outline,
                    label: 'このアプリについて',
                    onTap: _goAbout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// メニューボタン
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const double boxSize = 96;

    return Material(
      color: Colors.white.withOpacity(0.90),
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: boxSize,
          height: boxSize,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, left: 10, right: 10),
            child: Column(
              children: [
                Icon(icon, size: 34, color: Colors.black87),
                const Spacer(),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// このアプリについて
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('このアプリについて')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text(
              'デジタル御朱印帳',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              '御朱印を写真で記録し、寺院ごとに整理できるアプリです。\n\n'
              '・寺院一覧：コレクション表示\n'
              '・御朱印を記録：新しい寺院ページを作成\n\n'
              '将来的にQRコードから寺院ページへ誘導する機能も追加予定です。',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
