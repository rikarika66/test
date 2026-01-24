import 'package:flutter/material.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _nickController = TextEditingController();
  final _profileController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _nickController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  void _save() {
    // Formとしての整合性を保つ（今後validatorを足してもOK）
    final state = _formKey.currentState;
    if (state == null) return;
    state.save();

    final name = _nameController.text.trim();
    final nick = _nickController.text.trim();
    final profile = _profileController.text.trim();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存しました')),
    );

    // ✅ 入力値を呼び出し元へ返す（未使用警告も消えやすい）
    Navigator.pop(context, {
      'name': name,
      'nick': nick,
      'profile': profile,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ユーザー登録')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名前'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nickController,
                decoration: const InputDecoration(labelText: 'ニックネーム'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _profileController,
                decoration: const InputDecoration(labelText: '一言プロフィール'),
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
