import 'package:flutter/material.dart';

class BookPage extends StatelessWidget {
  const BookPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('御朱印帳')),
      body: const Center(
        child: Text('ここに御朱印帳の中身を作っていく'),
      ),
    );
  }
}
