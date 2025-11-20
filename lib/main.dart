import 'package:flutter/material.dart';

// 短いファイル名に変更
import 'pages/cover.dart';
import 'pages/user.dart';
import 'pages/book.dart';
import 'pages/cover_set.dart';
import 'pages/sns.dart';

void main() {
  runApp(const GoshuinApp());
}

class GoshuinApp extends StatelessWidget {
  const GoshuinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '御朱印帳アプリ',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const CoverPage(),
        '/user': (context) => const UserPage(),
        '/book': (context) => const BookPage(),
        '/cover-set': (context) => const CoverSetPage(),
        '/sns': (context) => const SnsPage(),
      },
    );
  }
}
