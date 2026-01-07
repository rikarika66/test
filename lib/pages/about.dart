import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('このアプリについて'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'デジタル御朱印帳\n\n'
          '寺院巡りの記録（写真・御朱印・参拝日など）を\n'
          '大切に残すためのアプリです。\n\n'
          '・寺院リスト：寺院の一覧\n'
          '・きろく：御朱印帳（記録）\n'
          '・このアプリについて：この説明ページ\n',
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
