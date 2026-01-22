import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class WebhookSettingsScreen extends StatefulWidget {
  const WebhookSettingsScreen({super.key});

  @override
  State<WebhookSettingsScreen> createState() => _WebhookSettingsScreenState();
}

class _WebhookSettingsScreenState extends State<WebhookSettingsScreen> {
  static const _knownEvents = <String>[
    'post.created',
    'post.updated',
    'post.deleted',
    'site.updated',
  ];

  late TextEditingController _urlController;
  late TextEditingController _secretController;
  bool _enabled = false;
  final Map<String, bool> _events = {};

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final s = appState.webhookSettings;
    _enabled = s.enabled;
    _urlController = TextEditingController(text: s.url);
    _secretController = TextEditingController(text: s.secret);
    for (final e in _knownEvents) {
      _events[e] = s.events.isEmpty ? true : (s.events[e] ?? false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _save(AppState appState) async {
    final settings = WebhookSettings(
      enabled: _enabled,
      url: _urlController.text.trim(),
      secret: _secretController.text,
      events: Map<String, bool>.from(_events),
    );
    await appState.setWebhookSettings(settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存')),
    );
  }

  Future<void> _test(AppState appState) async {
    await _save(appState);
    await appState.triggerWebhook(
      event: 'test',
      payload: {'message': 'Hello from FuwariStudio'},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已发送测试 webhook')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Webhook'),
            actions: [
              IconButton(
                tooltip: 'Save',
                onPressed: () => _save(appState),
                icon: const Icon(Icons.save_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('启用'),
                subtitle: const Text('在创建/修改/删除后触发自定义 Webhook'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Webhook URL',
                  hintText: 'https://example.com/webhook',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _secretController,
                decoration: const InputDecoration(
                  labelText: 'Secret（可选）',
                  helperText: '会作为 X-FuwariStudio-Secret 请求头发送',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('事件', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._knownEvents.map((e) {
                return CheckboxListTile(
                  title: Text(e),
                  value: _events[e] ?? false,
                  onChanged: (value) =>
                      setState(() => _events[e] = value == true),
                );
              }),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _enabled ? () => _test(appState) : null,
                icon: const Icon(Icons.send),
                label: const Text('发送测试'),
              ),
            ],
          ),
        );
      },
    );
  }
}

