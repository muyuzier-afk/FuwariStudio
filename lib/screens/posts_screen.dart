import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/post_entry.dart';
import '../screens/editor_screen.dart';
import '../screens/settings_screen.dart';

class _PostSearchDelegate extends SearchDelegate<PostEntry?> {
  _PostSearchDelegate({required List<PostEntry> posts})
      : _posts = List<PostEntry>.from(posts);

  final List<PostEntry> _posts;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Clear',
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  List<PostEntry> _filter() {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _posts;
    return _posts.where((p) {
      return p.title.toLowerCase().contains(q) ||
          p.relativePath.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = _filter();
    if (results.isEmpty) {
      return const Center(child: Text('没有匹配的文章'));
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final post = results[index];
        return ListTile(
          title: Text(post.title),
          subtitle: Text(post.relativePath, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => close(context, post),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  late Future<List<PostEntry>> _postsFuture;
  List<PostEntry> _lastPosts = const [];
  String? _activeFolder;

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

    final relativePath = p.posix.join('src', 'content', 'posts', '$slug.md');
    try {
      final entry = await appState.createPost(relativePath: relativePath, title: title);
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

  Future<void> _deletePost(AppState appState, PostEntry entry) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文章'),
        content: Text('确定删除“${entry.title}”吗？此操作会删除文件。'),
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

    if (result != true) return;
    try {
      await appState.deletePost(entry);
      _showSnack('已删除：${entry.title}');
      _refresh();
    } catch (error) {
      _showSnack('删除失败：$error');
    }
  }

  Future<void> _searchPosts(AppState appState) async {
    if (_lastPosts.isEmpty) {
      _showSnack('暂无文章可搜索');
      return;
    }
    final selected = await showSearch<PostEntry?>(
      context: context,
      delegate: _PostSearchDelegate(posts: _lastPosts),
    );
    if (!mounted || selected == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(entry: selected)),
    );
    _refresh();
  }

  List<PostEntry> _applyFolderFilter(AppState appState, List<PostEntry> posts) {
    final folder = _activeFolder;
    if (folder == null) return posts;
    return posts
        .where((p) => appState.foldersForPost(p.relativePath).contains(folder))
        .toList();
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
          appBar: AppBar(
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
                tooltip: 'Search',
                onPressed: appState.isBusy ? null : () => _searchPosts(appState),
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.settings_outlined),
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
              _lastPosts = posts;
              final filteredPosts = _applyFolderFilter(appState, posts);
              if (posts.isEmpty) {
                return Center(
                  child: Text(
                    '暂无文章，点击右下角新建',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          '最近文章',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 44,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: const Text('全部'),
                                selected: _activeFolder == null,
                                onSelected: (_) =>
                                    setState(() => _activeFolder = null),
                              ),
                            ),
                            for (final folder in appState.folders)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(folder),
                                  selected: _activeFolder == folder,
                                  onSelected: (_) =>
                                      setState(() => _activeFolder = folder),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                      sliver: SliverList.separated(
                        itemCount: filteredPosts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final post = filteredPosts[index];
                          return Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              title: Text(
                                post.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                post.relativePath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: post.draft
                                    ? Colors.orange.withAlpha(38)
                                    : Colors.green.withAlpha(38),
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
                              ),
                              onTap: () async {
                                final navigator = Navigator.of(context);
                                final entry =
                                    await appState.postRepository?.loadPost(
                                  File(post.file.path),
                                );
                                if (entry == null) return;
                                if (!context.mounted) return;
                                await navigator.push(
                                  MaterialPageRoute(
                                      builder: (_) => EditorScreen(entry: entry)),
                                );
                                if (!context.mounted) return;
                                _refresh();
                              },
                              onLongPress: () async {
                                final entry =
                                    await appState.postRepository?.loadPost(
                                  File(post.file.path),
                                );
                                if (entry == null) return;
                                if (!mounted) return;
                                await _deletePost(appState, entry);
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
