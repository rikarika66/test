import 'package:flutter/material.dart';

class SnsPage extends StatefulWidget {
  const SnsPage({super.key});

  @override
  State<SnsPage> createState() => _SnsPageState();
}

class _SnsPageState extends State<SnsPage> {
  final _xController = TextEditingController();
  final _instaController = TextEditingController();

  @override
  void dispose() {
    _xController.dispose();
    _instaController.dispose();
    super.dispose();
  }

  void _save() {
    final x = _xController.text.trim();
    final insta = _instaController.text.trim();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存しました')),
    );

    // ✅ 入力値を呼び出し元へ返す（未使用警告も出にくい）
    Navigator.pop(context, {'x': x, 'instagram': insta});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SNS登録')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _xController,
              decoration: const InputDecoration(labelText: 'X（Twitter）'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _instaController,
              decoration: const InputDecoration(labelText: 'Instagram'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
