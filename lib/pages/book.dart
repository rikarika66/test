import 'package:flutter/material.dart';

class BookPage extends StatelessWidget {
  const BookPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [
      {'temple': '正宗寺', 'date': '2025-11-13'},
      {'temple': '○○神社', 'date': '2025-10-01'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('御朱印帳')),
      body: ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, i) {
          return Card(
            child: ListTile(
              title: Text(data[i]['temple']!),
              subtitle: Text(data[i]['date']!),
            ),
          );
        },
      ),
    );
  }
}
