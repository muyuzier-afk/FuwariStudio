import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class WebhookSettingsScreen extends StatefulWidget {
  const WebhookSettingsScreen({super.key});

  @override
  State<WebhookSettingsScreen> createState() => _WebhookSettingsScreenState();
}

class _WebhookSettingsScreenState extends State<WebhookSettingsScreen> {
  static const Map<String, String> _eventLabels = {
    'post.created': '文章创建',
    'post.updated': '文章更新',
    'post.deleted': '文章删除',
    'site.updated': '站点信息更新',
  };

  List<EventRule> _rules = [];
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _rules = List<EventRule>.from(appState.eventRules);
    if (_rules.isEmpty) {
      _rules = [_buildDefaultRule()];
    }
  }

  EventRule _buildDefaultRule() {
    return EventRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '新事件',
      event: EventRule.defaultEvents.first,
      enabled: true,
      conditionText: '',
      thenAction: const WebhookAction(),
      elseEnabled: false,
      elseAction: const WebhookAction(),
    );
  }

  void _updateRule(EventRule updated) {
    setState(() {
      _rules = _rules.map((rule) => rule.id == updated.id ? updated : rule).toList();
      _dirty = true;
    });
  }

  void _deleteRule(EventRule target) {
    setState(() {
      _rules = _rules.where((rule) => rule.id != target.id).toList();
      _dirty = true;
    });
  }

  Future<void> _save(AppState appState) async {
    await appState.setEventRules(_rules);
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存')),
    );
  }

  Future<void> _testRule(AppState appState, EventRule rule) async {
    if (!rule.thenAction.isValid) {
      _showSnack('请先填写完整的 Webhook URL');
      return;
    }
    await appState.sendWebhookAction(
      action: rule.thenAction,
      event: rule.event,
      payload: {
        'title': '示例文章',
        'path': 'src/content/posts/example.md',
      },
      ruleName: rule.name,
      matched: true,
    );
    if (!mounted) return;
    _showSnack('已发送测试 Webhook');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('事件'),
            actions: [
              IconButton(
                tooltip: '保存',
                onPressed: _dirty ? () => _save(appState) : null,
                icon: const Icon(Icons.save_outlined),
              ),
              IconButton(
                tooltip: '新增事件',
                onPressed: () => setState(() {
                  _rules = [..._rules, _buildDefaultRule()];
                  _dirty = true;
                }),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_rules.isEmpty)
                Text(
                  '暂无事件，点击右上角新增。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ..._rules.map((rule) => _buildRuleCard(appState, rule)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRuleCard(AppState appState, EventRule rule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      child: ExpansionTile(
        key: ValueKey(rule.id),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(rule.name.trim().isEmpty ? '事件' : rule.name),
        subtitle: Text(_labelFor(rule.event)),
        trailing: Switch(
          value: rule.enabled,
          onChanged: (value) => _updateRule(rule.copyWith(enabled: value)),
        ),
        children: [
          TextFormField(
            initialValue: rule.name,
            decoration: const InputDecoration(
              labelText: '事件名称',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _updateRule(rule.copyWith(name: value)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: rule.event,
            decoration: const InputDecoration(
              labelText: '触发事件',
              border: OutlineInputBorder(),
            ),
            items: _eventLabels.keys
                .map(
                  (key) => DropdownMenuItem(
                    value: key,
                    child: Text('${_eventLabels[key]} ($key)'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              _updateRule(rule.copyWith(event: value));
            },
          ),
          const SizedBox(height: 16),
          Text('如果', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: rule.conditionText,
            decoration: const InputDecoration(
              labelText: '条件关键词（可选）',
              helperText: '为空则始终触发；匹配 payload 文本内容',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) =>
                _updateRule(rule.copyWith(conditionText: value)),
          ),
          const SizedBox(height: 16),
          Text('则（Webhook）', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _buildActionFields(
            action: rule.thenAction,
            onChanged: (next) => _updateRule(rule.copyWith(thenAction: next)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用否则分支'),
            value: rule.elseEnabled,
            onChanged: (value) =>
                _updateRule(rule.copyWith(elseEnabled: value)),
          ),
          if (rule.elseEnabled) ...[
            const SizedBox(height: 8),
            Text('否则（Webhook）', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildActionFields(
              action: rule.elseAction,
              onChanged: (next) =>
                  _updateRule(rule.copyWith(elseAction: next)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _deleteRule(rule),
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除事件'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _testRule(appState, rule),
                icon: const Icon(Icons.send_outlined),
                label: const Text('发送测试'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionFields({
    required WebhookAction action,
    required ValueChanged<WebhookAction> onChanged,
  }) {
    return Column(
      children: [
        TextFormField(
          initialValue: action.url,
          decoration: const InputDecoration(
            labelText: 'Webhook URL',
            hintText: 'https://example.com/webhook',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          onChanged: (value) => onChanged(action.copyWith(url: value)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: action.secret,
          decoration: const InputDecoration(
            labelText: '密钥（可选）',
            helperText: '会作为 X-FuwariStudio-Secret 请求头发送',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => onChanged(action.copyWith(secret: value)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: action.message,
          decoration: const InputDecoration(
            labelText: 'Webhook 文本',
            helperText: '支持 {event} {title} {path} {repo} {branch} {timestamp}',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (value) => onChanged(action.copyWith(message: value)),
        ),
      ],
    );
  }

  String _labelFor(String event) {
    return _eventLabels[event] ?? event;
  }
}
