import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../widgets/candle_easter_egg.dart';
import 'gaoguanghui_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<PackageInfo> _info() => PackageInfo.fromPlatform();

  String _formatVersion(PackageInfo info) {
    final build = info.buildNumber.trim();
    if (build.isEmpty || build == '0') return 'v${info.version}';
    return 'v${info.version}.$build';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: FutureBuilder<PackageInfo>(
        future: _info(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final versionText = (info == null) ? 'v1.0.0' : _formatVersion(info);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'FuwariStudio',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                versionText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '一个用于管理/编辑 Fuwari 博客文章的跨平台编辑器。',
              ),
              const SizedBox(height: 16),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.link),
                title: Text('项目地址'),
                subtitle: SelectableText('https://github.com/muyuzier-afk/FuwariStudio'),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: CandleEasterEgg(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GaoGuangHuiScreen()),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
