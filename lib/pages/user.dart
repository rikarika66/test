import 'package:flutter/material.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  String _nick = '';
  String _profile = '';

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
                decoration: const InputDecoration(labelText: '名前'),
                onSaved: (v) => _name = v ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'ニックネーム'),
                onSaved: (v) => _nick = v ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: '一言プロフィール'),
                maxLines: 3,
                onSaved: (v) => _profile = v ?? '',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  _formKey.currentState!.save();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('保存しました')),
                  );
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
