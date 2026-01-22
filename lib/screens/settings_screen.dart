import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

