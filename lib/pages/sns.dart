import 'package:flutter/material.dart';

class SnsPage extends StatefulWidget {
  const SnsPage({super.key});

  @override
  State<SnsPage> createState() => _SnsPageState();
}

class _SnsPageState extends State<SnsPage> {
  String _x = '';
  String _insta = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SNS登録')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'X（Twitter）'),
              onChanged: (v) => _x = v,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Instagram'),
              onChanged: (v) => _insta = v,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('保存しました')),
                );
                Navigator.pop(context);
              },
              child: const Text('保存'),
            )
          ],
        ),
      ),
    );
  }
}
