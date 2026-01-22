import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/site_config_service.dart';

class SiteConfigScreen extends StatefulWidget {
  const SiteConfigScreen({super.key});

  @override
  State<SiteConfigScreen> createState() => _SiteConfigScreenState();
}

class _SiteConfigScreenState extends State<SiteConfigScreen> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _langController = TextEditingController();
  final _themeHexController = TextEditingController();

  SiteConfigData? _loaded;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _keywordsController.dispose();
    _langController.dispose();
    _themeHexController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    try {
      final data = await appState.readSiteConfig();
      if (!mounted) return;
      if (data == null) {
        setState(() => _error = '未找到 src/config.ts（请先连接仓库）');
        return;
      }
      setState(() {
        _loaded = data;
        _error = null;
        _titleController.text = data.title;
        _subtitleController.text = data.subtitle;
        _descriptionController.text = data.description;
        _keywordsController.text = data.keywords.join(', ');
        _langController.text = data.lang;
        _themeHexController.text = data.themeHex;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  List<String> _parseKeywords(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _save(AppState appState) async {
    final data = SiteConfigData(
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      description: _descriptionController.text.trim(),
      keywords: _parseKeywords(_keywordsController.text),
      lang: _langController.text.trim(),
      themeHex: _themeHexController.text.trim(),
    );
    await appState.writeSiteConfig(data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存到 src/config.ts')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('站点信息'),
            actions: [
              IconButton(
                tooltip: 'Reload',
                onPressed: appState.isBusy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Save',
                onPressed: appState.isBusy ? null : () => _save(appState),
                icon: const Icon(Icons.save_outlined),
              ),
            ],
          ),
          body: _error != null
              ? Center(child: Text(_error!))
              : _loaded == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _subtitleController,
                          decoration: const InputDecoration(
                            labelText: 'subtitle',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _keywordsController,
                          decoration: const InputDecoration(
                            labelText: 'keywords（逗号分隔）',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _langController,
                          decoration: const InputDecoration(
                            labelText: 'lang',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _themeHexController,
                          decoration: const InputDecoration(
                            labelText: 'themeColor.hex',
                            hintText: '#ec4899',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed:
                              appState.isBusy ? null : () => _save(appState),
                          icon: const Icon(Icons.save),
                          label: const Text('保存'),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}

