import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const GoshuinApp());
}

class GoshuinApp extends StatefulWidget {
  const GoshuinApp({super.key});

  @override
  State<GoshuinApp> createState() => _GoshuinAppState();
}

class _GoshuinAppState extends State<GoshuinApp> {
  List<String> assetImages = [];

  @override
  void initState() {
    super.initState();
    _loadAssetImages();
  }

  /// assets/images/ フォルダ内の画像をすべて読み込む
  Future<void> _loadAssetImages() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = Map<String, dynamic>.from(
      manifestContent.isNotEmpty ? jsonDecode(manifestContent) : {},
    );

    /// パスに "assets/images/" を含み、PNG/JPG/JPEG を含むものだけ抽出
    final images = manifestMap.keys.where((String key) {
      return key.startsWith('assets/images/') &&
          (key.endsWith('.png') ||
              key.endsWith('.jpg') ||
              key.endsWith('.jpeg'));
    }).toList();

    setState(() {
      assetImages = images;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'デジタル御朱印帳',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('デジタル御朱印帳（assets版）'),
        ),
        body: assetImages.isEmpty
            ? const Center(child: Text("assets/images の画像を読み込んでいます…"))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: assetImages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AspectRatio(
                      aspectRatio: 3 / 2,
                      child: _AssetGoshuinCard(imagePath: assetImages[index]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// assets の画像をそのままカード表示するWidget
class _AssetGoshuinCard extends StatelessWidget {
  final String imagePath;

  const _AssetGoshuinCard({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            imagePath,
            fit: BoxFit.cover,
          ),
          Container(
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.all(12),
            child: Text(
              _todayString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black,
                    offset: Offset(1, 1),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 今日の日付を「2025年11月20日」形式で返す
  String _todayString() {
    final now = DateTime.now();
    return "${now.year}年${now.month}月${now.day}日";
  }
}
