import 'package:flutter/material.dart';

class CoverSetPage extends StatefulWidget {
  const CoverSetPage({super.key});

  @override
  State<CoverSetPage> createState() => _CoverSetPageState();
}

class _CoverSetPageState extends State<CoverSetPage> {
  String _title = '御朱印帳';
  Color _color = Colors.red;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('表紙設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 200,
              height: 280,
              decoration: BoxDecoration(
                color: _color.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                _title,
                style: const TextStyle(fontSize: 22, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: _title,
              decoration: const InputDecoration(labelText: 'タイトル'),
              onChanged: (v) => setState(() => _title = v),
            ),
            const SizedBox(height: 16),
            Wrap(
              children: [
                _colorCircle(Colors.red),
                _colorCircle(Colors.blue),
                _colorCircle(Colors.green),
                _colorCircle(Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorCircle(Color c) {
    return GestureDetector(
      onTap: () => setState(() => _color = c),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            width: _color == c ? 3 : 1,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
