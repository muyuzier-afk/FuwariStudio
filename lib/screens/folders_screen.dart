import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  Future<String?> _promptText(
    BuildContext context, {
    required String title,
    String? initialValue,
    String? hintText,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result != true) return null;
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final folders = appState.folders;
        return Scaffold(
          appBar: AppBar(
            title: const Text('文件夹'),
            actions: [
              IconButton(
                tooltip: 'Add',
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final name = await _promptText(
                    context,
                    title: '新增文件夹',
                    hintText: '例如：AI / 日记 / 教程',
                  );
                  if (name == null) return;
                  await appState.addFolder(name);
                },
              ),
            ],
          ),
          body: folders.isEmpty
              ? const Center(child: Text('暂无文件夹，点右上角添加'))
              : ListView.separated(
                  itemCount: folders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final name = folders[index];
                    return ListTile(
                      title: Text(name),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'rename') {
                            final next = await _promptText(
                              context,
                              title: '重命名',
                              initialValue: name,
                            );
                            if (next == null) return;
                            await appState.renameFolder(name, next);
                          } else if (value == 'delete') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('删除文件夹'),
                                content: Text('确定删除“$name”吗？不会删除文章，只会取消分类。'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await appState.deleteFolder(name);
                            }
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'rename', child: Text('重命名')),
                          PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

