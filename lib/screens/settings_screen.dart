import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'about_screen.dart';
import 'folders_screen.dart';
import 'webhook_settings_screen.dart';
import 'site_config_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _updateToken(BuildContext context, AppState appState) async {
    final controller = TextEditingController(text: appState.token ?? '');
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('更新 GitHub Token'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Token',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      );

      if (result == true) {
        await appState.saveToken(controller.text.trim());
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token 已更新')),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final pref = appState.themePreference;
        final followSystem = pref == ThemePreference.system;
        final manualDark = pref == ThemePreference.dark;

        return Scaffold(
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            children: [
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('跟随系统'),
                subtitle: const Text('默认使用系统原生黑夜模式'),
                value: followSystem,
                onChanged: (value) async {
                  await appState.setThemePreference(
                    value ? ThemePreference.system : ThemePreference.light,
                  );
                },
              ),
              SwitchListTile(
                title: const Text('黑夜模式'),
                subtitle: followSystem
                    ? const Text('关闭“跟随系统”后可手动切换')
                    : null,
                value: manualDark,
                onChanged: followSystem
                    ? null
                    : (value) async {
                        await appState.setThemePreference(
                          value ? ThemePreference.dark : ThemePreference.light,
                        );
                      },
              ),
              SwitchListTile(
                title: const Text('自动保存并推送'),
                subtitle: const Text('保存文章后自动提交并推送到 GitHub'),
                value: appState.autoCommit,
                onChanged: (value) async {
                  await appState.setAutoCommit(value);
                },
              ),
              ListTile(
                title: const Text('更新 GitHub Token'),
                subtitle:
                    Text((appState.token?.isNotEmpty == true) ? '已设置' : '未设置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await _updateToken(context, appState);
                },
              ),
              const Divider(height: 24),
              ListTile(
                title: const Text('文件夹'),
                subtitle: const Text('用于分类文章（类似标签）'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FoldersScreen()),
                  );
                },
              ),
              ListTile(
                title: const Text('事件'),
                subtitle: const Text('创建事件规则并推送 Webhook'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WebhookSettingsScreen()),
                  );
                },
              ),
              ListTile(
                title: const Text('站点信息'),
                subtitle: const Text('编辑 src/config.ts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SiteConfigScreen()),
                  );
                },
              ),
              const Divider(height: 24),
              ListTile(
                title: const Text('关于'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
