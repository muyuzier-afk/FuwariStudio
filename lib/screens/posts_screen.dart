import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/post_entry.dart';
import '../screens/editor_screen.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  late Future<List<PostEntry>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadPosts();
  }

  Future<List<PostEntry>> _loadPosts() async {
    final appState = context.read<AppState>();
    final repo = appState.postRepository;
    if (repo == null) return [];
    return repo.listPosts();
  }

  Future<void> _refresh() async {
    setState(() {
      _postsFuture = _loadPosts();
    });
  }

  Future<void> _createPost(AppState appState) async {
    final titleController = TextEditingController();
    final slugController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建文章'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '标题'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: slugController,
              decoration: const InputDecoration(
                labelText: '文件名（slug）',
                hintText: 'my-first-post',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final title = titleController.text.trim();
    final slug = slugController.text.trim();
    if (title.isEmpty || slug.isEmpty) {
      _showSnack('Title and filename are required');
      return;
    }

    final repo = appState.postRepository;
    if (repo == null) return;

    final relativePath = p.posix.join('src', 'content', 'posts', '$slug.md');
    try {
      final entry = await repo.createPost(
        relativePath: relativePath,
        title: title,
      );
      appState.markDirty(entry.relativePath);
      if (appState.autoCommit) {
        await appState.commitDirty(message: 'Add $slug');
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditorScreen(entry: entry)),
      );
      _refresh();
    } catch (error) {
      _showSnack('创建失败: $error');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _commitDirty(AppState appState) async {
    try {
      final sha = await appState.commitDirty(message: 'Update posts');
      if (sha == null) {
        _showSnack('没有待推送的更改');
        return;
      }
      final shortSha = sha.substring(0, 7);
      final config = appState.config;
      final target = (config == null)
          ? ''
          : ' → ${config.owner}/${config.repo}@${config.branch}';
      _showSnack('已推送：$shortSha$target');
    } catch (error) {
      _showSnack('推送失败: $error');
    }
  }

  Future<void> _updateToken(AppState appState) async {
    final controller = TextEditingController(text: appState.token ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update GitHub token'),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      await appState.saveToken(controller.text.trim());
      _showSnack('Token 已更新');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0C0F16),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              '文章管理',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: '提交并推送',
                onPressed:
                    appState.isBusy ? null : () => _commitDirty(appState),
                icon: const Icon(Icons.cloud_upload_outlined),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'auto') {
                    await appState.setAutoCommit(!appState.autoCommit);
                  } else if (value == 'token') {
                    await _updateToken(appState);
                  }
                },
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: 'auto',
                    checked: appState.autoCommit,
                    child: const Text('自动保存并推送'),
                  ),
                  const PopupMenuItem(
                    value: 'token',
                    child: Text('更新 GitHub Token'),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: appState.isBusy ? null : () => _createPost(appState),
            label: const Text('新建文章'),
            icon: const Icon(Icons.add),
          ),
          body: FutureBuilder<List<PostEntry>>(
            future: _postsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final posts = snapshot.data ?? [];
              if (posts.isEmpty) {
                return const Center(
                  child: Text(
                    '暂无文章，点击右下角新建',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          '最近文章',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                      sliver: SliverList.separated(
                        itemCount: posts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return Card(
                            color: const Color(0xFF141926),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              title: Text(
                                post.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                post.relativePath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: post.draft
                                    ? Colors.orange.withOpacity(0.15)
                                    : Colors.green.withOpacity(0.15),
                                child: Icon(
                                  post.draft
                                      ? Icons.pending_outlined
                                      : Icons.check_circle_outline,
                                  color: post.draft
                                      ? Colors.orange
                                      : Colors.greenAccent,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Colors.white54,
                              ),
                              onTap: () async {
                                final entry =
                                    await appState.postRepository?.loadPost(
                                  File(post.file.path),
                                );
                                if (entry == null) return;
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditorScreen(entry: entry),
                                  ),
                                );
                                _refresh();
                              },
                            ),
                          );
                        },
                      ),
                    ),
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
