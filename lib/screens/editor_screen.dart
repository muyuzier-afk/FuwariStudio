import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/post_entry.dart';
import '../widgets/markdown_preview.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.entry});

  final PostEntry entry;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _bodyController;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _tagsController;
  late TextEditingController _tagAddController;
  late TextEditingController _categoryController;
  late TextEditingController _imageController;
  late TextEditingController _publishedController;
  late TextEditingController _updatedController;
  late TextEditingController _langController;
  bool _draft = false;
  String _previewMarkdown = '';
  Timer? _previewTimer;
  String _themeHex = '#ec4899';
  bool _livePreview = false;
  bool _previewDirty = false;

  @override
  void initState() {
    super.initState();
    final data = widget.entry.frontMatter.data;
    _bodyController = TextEditingController(text: widget.entry.body);
    _titleController =
        TextEditingController(text: data['title']?.toString() ?? '');
    _descController =
        TextEditingController(text: data['description']?.toString() ?? '');
    _tagsController = TextEditingController(
      text: (data['tags'] is List) ? (data['tags'] as List).join(', ') : '',
    );
    _tagAddController = TextEditingController();
    _categoryController =
        TextEditingController(text: data['category']?.toString() ?? '');
    _imageController =
        TextEditingController(text: data['image']?.toString() ?? '');
    _publishedController =
        TextEditingController(text: _formatDate(data['published']));
    _updatedController =
        TextEditingController(text: _formatDate(data['updated']));
    _langController =
        TextEditingController(text: data['lang']?.toString() ?? '');
    _draft = data['draft'] == true ||
        (data['draft'] is String &&
            (data['draft'] as String).toLowerCase() == 'true');
    _previewMarkdown = widget.entry.body;
    _loadThemeHex();
  }

  String _formatDate(dynamic value) {
    if (value is DateTime) {
      return DateFormat('yyyy-MM-dd').format(value);
    }
    return value?.toString() ?? '';
  }

  Future<void> _loadThemeHex() async {
    final appState = context.read<AppState>();
    final hex = await appState.readThemeHex();
    if (!mounted) return;
    setState(() {
      _themeHex = hex;
    });
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _bodyController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _tagsController.dispose();
    _tagAddController.dispose();
    _categoryController.dispose();
    _imageController.dispose();
    _publishedController.dispose();
    _updatedController.dispose();
    _langController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildFrontMatter() {
    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    DateTime? parseDate(String value) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) return null;
      return DateTime.tryParse(cleaned);
    }

    return {
      'title': _titleController.text.trim(),
      'published': parseDate(_publishedController.text) ?? DateTime.now(),
      'updated': parseDate(_updatedController.text),
      'description': _descController.text.trim(),
      'image': _imageController.text.trim(),
      'tags': tags,
      'category': _categoryController.text.trim(),
      'draft': _draft,
      'lang': _langController.text.trim(),
    };
  }

  Future<void> _save(AppState appState) async {
    final repo = appState.postRepository;
    if (repo == null) return;

    try {
      await repo.savePost(
        entry: widget.entry,
        frontMatter: _buildFrontMatter(),
        body: _bodyController.text,
      );
      appState.markDirty(widget.entry.relativePath);

      if (appState.autoCommit) {
        final sha = await appState.commitDirty(
          message: 'Update ${widget.entry.relativePath}',
        );
        if (!mounted) return;
        if (sha != null) {
          final shortSha = sha.substring(0, 7);
          final config = appState.config;
          final target = (config == null)
              ? ''
              : ' → ${config.owner}/${config.repo}@${config.branch}';
          _showSnack('已保存并推送：$shortSha$target');
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    } catch (error) {
      _showSnack('保存失败: $error');
    }
  }

  void _schedulePreviewUpdate(String value) {
    if (!_livePreview) return;
    _previewTimer?.cancel();
    final ms = value.length > 60000
        ? 1200
        : value.length > 25000
            ? 800
            : 300;
    _previewTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() {
        _previewMarkdown = value;
        _previewDirty = false;
      });
    });
  }

  void _onBodyChanged(String value) {
    if (_livePreview) {
      _schedulePreviewUpdate(value);
      return;
    }
    if (!_previewDirty) {
      setState(() => _previewDirty = true);
    }
  }

  Future<void> _insertImage(AppState appState) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;
    final source = File(result.files.single.path!);
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      _showSnack('不支持的图片格式');
      return;
    }

    final selectedWidth = await _pickResizeWidth(decoded.width);
    if (selectedWidth == null) return;

    img.Image output = decoded;
    if (selectedWidth > 0 && selectedWidth < decoded.width) {
      output = img.copyResize(decoded, width: selectedWidth);
    }

    final ext = p.extension(source.path).toLowerCase();
    final baseName = p.basenameWithoutExtension(source.path);
    final fileName = '${baseName}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destDir = widget.entry.file.parent;
    final destFile = File(p.join(destDir.path, fileName));

    List<int> encoded;
    if (ext == '.jpg' || ext == '.jpeg') {
      encoded = img.encodeJpg(output, quality: 88);
    } else {
      encoded = img.encodePng(output);
    }

    await destFile.writeAsBytes(encoded, flush: true);

    final relativePath =
        p.posix.joinAll(p.split(p.relative(destFile.path, from: destDir.path)));
    final insertText = '![$baseName]($relativePath)';
    final selection = _bodyController.selection;
    final text = _bodyController.text;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, insertText);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insertText.length),
    );

    _schedulePreviewUpdate(newText);

    final imageRepoPath = p.posix.joinAll(
        p.split(p.relative(destFile.path, from: appState.config!.localPath)));
    appState.markDirty(imageRepoPath);
    appState.markDirty(widget.entry.relativePath);
    await _save(appState);
  }

  Future<int?> _pickResizeWidth(int originalWidth) async {
    int current = originalWidth;
    return showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('调整图片大小'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('最大宽度：$current px'),
                  Slider(
                    value: current.toDouble(),
                    min: 320,
                    max: originalWidth.toDouble(),
                    divisions: (originalWidth / 80).floor().clamp(1, 20),
                    label: '$current',
                    onChanged: (value) {
                      setState(() => current = value.round());
                    },
                  ),
                  TextButton(
                    onPressed: () => setState(() => current = originalWidth),
                    child: const Text('使用原始尺寸'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, current),
                  child: const Text('应用'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickCoverImage(AppState appState) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;
    final source = File(result.files.single.path!);
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      _showSnack('不支持的图片格式');
      return;
    }

    final selectedWidth = await _pickResizeWidth(decoded.width);
    if (selectedWidth == null) return;

    img.Image output = decoded;
    if (selectedWidth > 0 && selectedWidth < decoded.width) {
      output = img.copyResize(decoded, width: selectedWidth);
    }

    final ext = p.extension(source.path).toLowerCase();
    final baseName = p.basenameWithoutExtension(source.path);
    final fileName = '${baseName}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destDir = widget.entry.file.parent;
    final destFile = File(p.join(destDir.path, fileName));

    List<int> encoded;
    if (ext == '.jpg' || ext == '.jpeg') {
      encoded = img.encodeJpg(output, quality: 88);
    } else {
      encoded = img.encodePng(output);
    }

    await destFile.writeAsBytes(encoded, flush: true);
    final relativePath =
        p.posix.joinAll(p.split(p.relative(destFile.path, from: destDir.path)));
    setState(() => _imageController.text = relativePath);

    final imageRepoPath = p.posix.joinAll(
        p.split(p.relative(destFile.path, from: appState.config!.localPath)));
    appState.markDirty(imageRepoPath);
    appState.markDirty(widget.entry.relativePath);
    await _save(appState);
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
        final isWide = MediaQuery.of(context).size.width > 1000;
        final editor = _buildEditor(appState);
        final preview = MarkdownPreview(
          markdown: _previewMarkdown,
          basePath: widget.entry.file.parent.path,
          themeHex: _themeHex,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.entry.title.isEmpty ? '未命名文章' : widget.entry.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                tooltip: '保存',
                onPressed: appState.isBusy ? null : () => _save(appState),
                icon: const Icon(Icons.save_outlined),
              ),
              IconButton(
                tooltip: '插入图片',
                onPressed:
                    appState.isBusy ? null : () => _insertImage(appState),
                icon: const Icon(Icons.image_outlined),
              ),
              IconButton(
                tooltip: '提交并推送',
                onPressed: appState.isBusy
                    ? null
                    : () async {
                        try {
                          final sha = await appState.commitDirty(
                              message: 'Update posts');
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
                      },
                icon: const Icon(Icons.cloud_upload_outlined),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: isWide
                ? Row(
                    children: [
                      Expanded(child: editor),
                      const SizedBox(width: 12),
                      Expanded(child: _buildPreviewPane(preview)),
                    ],
                  )
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: '编写'),
                            Tab(text: '预览'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              editor,
                              _buildPreviewPane(preview),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildEditor(AppState appState) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final textColor = cs.onSurface;
    final labelColor = cs.onSurfaceVariant;
    final helperColor = cs.onSurfaceVariant;
    final panelColor = theme.cardColor;
    final panelBorder = cs.outlineVariant;
    final subtleFill =
        isDark ? cs.surfaceContainerHighest : const Color(0xFFF8FAFC);
    final shadowColor =
        isDark ? Colors.black.withAlpha(64) : Colors.black.withAlpha(8);

    InputDecoration decoration(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor),
        floatingLabelStyle: TextStyle(color: textColor),
      );
    }

    final fieldTextStyle = TextStyle(color: textColor);

    List<String> currentTags() {
      return _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    void setTags(List<String> tags) {
      _tagsController.text = tags.join(', ');
    }

    return ListView(
      padding: const EdgeInsets.all(4),
      children: [
        Container(
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: panelBorder),
            boxShadow: isDark
                ? const []
                : [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 12),
                  initiallyExpanded: true,
                  title: Row(
                    children: [
                      Icon(Icons.tune, size: 20, color: labelColor),
                      const SizedBox(width: 8),
                      Text(
                        '文章信息',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    widget.entry.relativePath,
                    style: TextStyle(color: helperColor, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            style: fieldTextStyle,
                            decoration: decoration('标题').copyWith(
                              prefixIcon: const Icon(Icons.title),
                              helperText: '显示在站点文章列表和页面标题',
                              helperStyle: TextStyle(color: helperColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: subtleFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: panelBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Text('草稿',
                                    style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w600)),
                              ),
                              Switch(
                                value: _draft,
                                onChanged: (value) =>
                                    setState(() => _draft = value),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      style: fieldTextStyle,
                      maxLines: 2,
                      decoration: decoration('摘要').copyWith(
                        prefixIcon: const Icon(Icons.short_text),
                        helperText: '用于 SEO / 列表简介（可选）',
                        helperStyle: TextStyle(color: helperColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: subtleFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: panelBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '标签',
                            style: TextStyle(
                                color: textColor, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...currentTags().map((tag) {
                                return InputChip(
                                  label: Text(tag),
                                  onDeleted: () {
                                    final tags = currentTags()..remove(tag);
                                    setState(() => setTags(tags));
                                  },
                                );
                              }),
                              SizedBox(
                                width: 220,
                                child: TextField(
                                  controller: _tagAddController,
                                  style: fieldTextStyle,
                                  decoration: const InputDecoration(
                                    hintText: '添加标签…（回车）',
                                    isDense: true,
                                  ),
                                  onSubmitted: (value) {
                                    final v = value.trim();
                                    if (v.isEmpty) return;
                                    final tags = currentTags();
                                    if (!tags.contains(v)) tags.add(v);
                                    setState(() {
                                      setTags(tags);
                                      _tagAddController.clear();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '也支持用逗号分隔：${_tagsController.text.isEmpty ? '例如：flutter, 笔记' : _tagsController.text}',
                            style: TextStyle(
                                color: helperColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _categoryController,
                            style: fieldTextStyle,
                            decoration: decoration('分类').copyWith(
                              prefixIcon: const Icon(Icons.folder_open),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _langController,
                            style: fieldTextStyle,
                            decoration: decoration('语言').copyWith(
                              prefixIcon: const Icon(Icons.language),
                              helperText: '例如：zh_CN / en',
                              helperStyle: TextStyle(color: helperColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _publishedController,
                            style: fieldTextStyle,
                            decoration: decoration('发布日期').copyWith(
                              prefixIcon: const Icon(Icons.calendar_today),
                              helperText: '支持 YYYY-MM-DD 或自动选择',
                              helperStyle: TextStyle(color: helperColor),
                              suffixIcon: IconButton(
                                tooltip: '选择日期',
                                icon: const Icon(Icons.event),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.tryParse(
                                            _publishedController.text.trim()) ??
                                        DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked == null) return;
                                  setState(() => _publishedController.text =
                                      DateFormat('yyyy-MM-dd').format(picked));
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _updatedController,
                            style: fieldTextStyle,
                            decoration: decoration('更新日期').copyWith(
                              prefixIcon: const Icon(Icons.update),
                              helperText: '留空则不写入',
                              helperStyle: TextStyle(color: helperColor),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: '清空',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => setState(
                                        () => _updatedController.clear()),
                                  ),
                                  IconButton(
                                    tooltip: '选择日期',
                                    icon: const Icon(Icons.event),
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.tryParse(
                                                _updatedController.text
                                                    .trim()) ??
                                            DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked == null) return;
                                      setState(() => _updatedController.text =
                                          DateFormat('yyyy-MM-dd')
                                              .format(picked));
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _imageController,
                            style: fieldTextStyle,
                            decoration: decoration('封面图片').copyWith(
                              prefixIcon: const Icon(Icons.image_outlined),
                              helperText: '相对路径（通常与文章同目录）',
                              helperStyle: TextStyle(color: helperColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: appState.isBusy
                              ? null
                              : () => _pickCoverImage(appState),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('选择图片'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: panelBorder),
            boxShadow: isDark
                ? const []
                : [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildToolbar(appState),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Divider(height: 1, color: panelBorder),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 360),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _bodyController,
                    maxLines: null,
                    minLines: 18,
                    onChanged: _onBodyChanged,
                    decoration: const InputDecoration(
                      hintText: '在此编写 Markdown 内容，左侧工具栏可快速插入格式。',
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 14,
                      height: 1.5,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewPane(Widget preview) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final panelColor = theme.cardColor;
    final panelBorder = cs.outlineVariant;
    final headerFill =
        isDark ? cs.surfaceContainerHighest : const Color(0xFFF8FAFC);
    final shadowColor =
        isDark ? Colors.black.withAlpha(64) : Colors.black.withAlpha(8);

    return Container(
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: headerFill,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: panelBorder)),
            ),
            child: Row(
              children: [
                const Text(
                  '预览',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '实时预览',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    Switch(
                      value: _livePreview,
                      onChanged: (value) {
                        setState(() {
                          _livePreview = value;
                          if (_livePreview) {
                            _previewMarkdown = _bodyController.text;
                            _previewDirty = false;
                          }
                        });
                      },
                    ),
                  ],
                ),
                if (_previewDirty)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text(
                      '未更新',
                      style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                IconButton(
                  tooltip: '刷新预览',
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () {
                    setState(() {
                      _previewMarkdown = _bodyController.text;
                      _previewDirty = false;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Container(
                color: headerFill,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: preview,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(AppState appState) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final toolbarFill =
        isDark ? cs.surfaceContainerHighest : const Color(0xFFF8FAFC);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: toolbarFill,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Wrap(
        spacing: 2,
        runSpacing: 4,
        children: [
          _toolbarButton(Icons.title, '标题', () => _insertHeading(1)),
          _toolbarButton(Icons.format_bold, '粗体',
              () => _applyInline('**', '**', placeholder: '粗体文本')),
          _toolbarButton(Icons.format_italic, '斜体',
              () => _applyInline('*', '*', placeholder: '斜体文本')),
          _toolbarButton(Icons.code, '行内代码',
              () => _applyInline('`', '`', placeholder: 'code')),
          _toolbarButton(Icons.format_quote, '引用', _insertQuote),
          _toolbarButton(Icons.format_list_bulleted, '无序列表',
              () => _applyMultilinePrefix('- ')),
          _toolbarButton(Icons.format_list_numbered, '有序列表',
              () => _applyMultilinePrefix('1. ')),
          _toolbarButton(Icons.check_box_outlined, '任务列表',
              () => _applyMultilinePrefix('- [ ] ')),
          _toolbarButton(Icons.horizontal_rule, '分割线', _insertDivider),
          _toolbarButton(Icons.insert_link, '链接', _insertLink),
          _toolbarButton(Icons.data_object, '代码块', _insertCodeBlock),
          _toolbarButton(
              Icons.photo_outlined, '插入图片', () => _insertImage(appState)),
        ],
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String tooltip, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 36,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
  }

  void _applyInline(String prefix, String suffix, {String placeholder = ''}) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < start ? start : selection.end;
    final selected = text.substring(start, end);
    final content = selected.isEmpty ? placeholder : selected;
    final inserted = '$prefix$content$suffix';
    final newText = text.replaceRange(start, end, inserted);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
    _schedulePreviewUpdate(newText);
  }

  void _applyLinePrefix(String prefix) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.start < 0 ? 0 : selection.start;
    final lineStart = text.lastIndexOf('\n', start - 1) + 1;
    final lineEnd =
        text.indexOf('\n', selection.end < 0 ? start : selection.end);
    final end = lineEnd == -1 ? text.length : lineEnd;
    final line = text.substring(lineStart, end);
    final updatedLine = line.startsWith(prefix) ? line : '$prefix$line';
    final newText = text.replaceRange(lineStart, end, updatedLine);
    final cursor = start + (updatedLine.length - line.length);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _schedulePreviewUpdate(newText);
  }

  void _applyMultilinePrefix(String prefix) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.start < 0 ? 0 : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final selected = text.substring(start, end);
    if (selected.isEmpty) {
      _applyLinePrefix(prefix);
      return;
    }
    final updated = selected
        .split('\n')
        .map((line) => line.isEmpty ? prefix.trimRight() : '$prefix$line')
        .join('\n');
    final newText = text.replaceRange(start, end, updated);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + updated.length),
    );
    _schedulePreviewUpdate(newText);
  }

  void _insertHeading(int level) {
    _applyLinePrefix('${'#' * level} ');
  }

  void _insertQuote() {
    _applyLinePrefix('> ');
  }

  void _insertDivider() {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    const divider = '\n\n---\n\n';
    final newText = text.replaceRange(
        start, selection.end < 0 ? start : selection.end, divider);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + divider.length),
    );
    _schedulePreviewUpdate(newText);
  }

  void _insertCodeBlock() {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? start : selection.end;
    final selected = text.substring(start, end);
    final block = '```\n${selected.isEmpty ? 'code' : selected}\n```\n';
    final newText = text.replaceRange(start, end, block);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + block.length),
    );
    _schedulePreviewUpdate(newText);
  }

  void _insertLink() {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? start : selection.end;
    final selected = text.substring(start, end);
    final insert = '[${selected.isEmpty ? '链接文本' : selected}](https://)';
    final newText = text.replaceRange(start, end, insert);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    _schedulePreviewUpdate(newText);
  }
}
