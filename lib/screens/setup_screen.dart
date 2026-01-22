import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _repoController = TextEditingController();
  final _tokenController = TextEditingController();

  @override
  void dispose() {
    _repoController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap(AppState appState) async {
    final repoUrl = _repoController.text.trim();
    final token = _tokenController.text.trim();

    if (repoUrl.isEmpty || token.isEmpty) {
      _showSnack('仓库地址和 Token 不能为空');
      return;
    }

    try {
      await appState.bootstrapRepo(repoUrl, token);
    } catch (error) {
      _showSnack(_formatBootstrapError(error));
    }
  }

  String _formatBootstrapError(Object error) {
    final text = error.toString();
    if (text.contains('Failed host lookup') ||
        text.contains('No address associated with hostname') ||
        text.contains('Network error while calling GitHub API')) {
      return '无法连接到 GitHub（api.github.com）。请检查网络/DNS；Android 版请确认已添加 INTERNET 权限。';
    }
    return '初始化失败：$text';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 6,
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '连接到 GitHub',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '首次会自动下载最新仓库源码并进入文章目录。',
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _repoController,
                        decoration: const InputDecoration(
                          labelText: '仓库地址（例如 https://github.com/owner/repo）',
                          hintText: 'https://github.com/owner/repo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tokenController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'GitHub Token',
                          helperText:
                              'Fine-grained：Metadata(读) + Contents(读写)；Classic：public_repo/repo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: appState.isBusy
                              ? null
                              : () => _bootstrap(appState),
                          child: appState.isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('下载并打开'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
