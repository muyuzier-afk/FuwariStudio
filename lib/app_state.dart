import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/repo_config.dart';
import 'models/post_entry.dart';
import 'services/github_service.dart';
import 'services/post_repository.dart';
import 'services/repo_bootstrapper.dart';
import 'services/webhook_service.dart';
import 'services/site_config_service.dart';

class AppState extends ChangeNotifier {
  AppState()
      : _secureStorage = const FlutterSecureStorage(),
        _gitHubService = GitHubService(),
        _webhookService = WebhookService();

  final FlutterSecureStorage _secureStorage;
  final GitHubService _gitHubService;
  final WebhookService _webhookService;
  final SiteConfigService _siteConfigService = SiteConfigService();

  RepoConfig? _config;
  String? _token;
  bool _autoCommit = true;
  bool _busy = false;
  final Set<String> _dirtyFiles = {};
  ThemePreference _themePreference = ThemePreference.system;
  Color _themeSeedColor = const Color(0xFFEC4899);
  List<String> _folders = const [];
  Map<String, List<String>> _postFolders = const {};
  List<EventRule> _eventRules = const [];

  RepoConfig? get config => _config;
  String? get token => _token;
  bool get autoCommit => _autoCommit;
  bool get isBusy => _busy;
  bool get hasRepo => _config != null;
  ThemeMode get themeMode => _themePreference.toThemeMode();
  ThemePreference get themePreference => _themePreference;
  Color get themeSeedColor => _themeSeedColor;
  List<String> get folders => List.unmodifiable(_folders);
  List<String> foldersForPost(String relativePath) =>
      List.unmodifiable(_postFolders[relativePath] ?? const []);
  List<EventRule> get eventRules => List.unmodifiable(_eventRules);

  PostRepository? get postRepository =>
      _config == null ? null : PostRepository(_config!);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('repo_config');
    _autoCommit = prefs.getBool('auto_commit') ?? true;
    _themePreference = ThemePreference.fromString(
      prefs.getString('theme_preference'),
    );
    _folders = _decodeStringList(prefs.getString('folders')) ?? const [];
    _postFolders = _decodePostFolders(prefs.getString('post_folders')) ?? const {};
    _eventRules = _decodeEventRules(prefs.getString('event_rules')) ??
        _decodeLegacyWebhookSettings(prefs.getString('webhook_settings')) ??
        const [];
    _token = await _secureStorage.read(key: 'github_token');

    if (configJson != null) {
      final decoded = jsonDecode(configJson) as Map<String, dynamic>;
      final config = RepoConfig.fromJson(decoded);
      if (Directory(config.localPath).existsSync()) {
        _config = config;
      }
    }

    await refreshThemeSeedColor();
    notifyListeners();
  }

  Future<void> setEventRules(List<EventRule> rules) async {
    _eventRules = List<EventRule>.unmodifiable(rules);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('event_rules', jsonEncode(_eventRules.map((r) => r.toJson()).toList()));
    notifyListeners();
  }

  Future<void> triggerWebhook({
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    for (final rule in _eventRules) {
      if (!rule.enabled) continue;
      if (rule.event != event) continue;

      final matches = rule.matches(payload);
      final action = matches ? rule.thenAction : rule.elseActionOrNull;
      if (action == null || !action.isValid) continue;

      await _sendWebhookAction(
        action: action,
        event: event,
        payload: payload,
        ruleName: rule.name,
        matched: matches,
      );
    }
  }

  Future<void> sendWebhookAction({
    required WebhookAction action,
    required String event,
    required Map<String, dynamic> payload,
    String? ruleName,
    bool matched = true,
  }) async {
    if (!action.isValid) return;
    await _sendWebhookAction(
      action: action,
      event: event,
      payload: payload,
      ruleName: ruleName,
      matched: matched,
    );
  }

  Future<void> _sendWebhookAction({
    required WebhookAction action,
    required String event,
    required Map<String, dynamic> payload,
    String? ruleName,
    bool matched = true,
  }) async {
    final uri = Uri.tryParse(action.url.trim());
    if (uri == null) return;

    final timestamp = DateTime.now().toUtc().toIso8601String();
    final repoInfo = _config == null
        ? null
        : {
            'owner': _config!.owner,
            'repo': _config!.repo,
            'branch': _config!.branch,
          };
    final message = _renderTemplate(
      action.message,
      {
        'event': event,
        'timestamp': timestamp,
        'owner': _config?.owner ?? '',
        'repo': _config?.repo ?? '',
        'branch': _config?.branch ?? '',
        'path': payload['path']?.toString() ?? '',
        'title': payload['title']?.toString() ?? '',
      },
    );

    final body = <String, dynamic>{
      'event': event,
      'timestamp': timestamp,
      'repo': repoInfo,
      'payload': payload,
      'rule': ruleName,
      'matched': matched,
    };
    if (message.trim().isNotEmpty) {
      body['message'] = message;
    }

    try {
      await _webhookService.sendJson(
        uri: uri,
        secret: action.secret,
        body: body,
      );
    } catch (_) {
      // Best-effort: webhook should not block user operations.
    }
  }

  Future<void> addFolder(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return;
    if (_folders.contains(cleaned)) return;
    _folders = [..._folders, cleaned]..sort();
    await _persistFolders();
    notifyListeners();
  }

  Future<void> renameFolder(String oldName, String newName) async {
    final next = newName.trim();
    if (next.isEmpty) return;
    if (oldName == next) return;
    if (!_folders.contains(oldName)) return;
    if (_folders.contains(next)) {
      throw Exception('Folder already exists: $next');
    }
    _folders = _folders.map((f) => f == oldName ? next : f).toList()..sort();
    final updated = <String, List<String>>{};
    for (final entry in _postFolders.entries) {
      final replaced = entry.value.map((f) => f == oldName ? next : f).toSet();
      updated[entry.key] = replaced.toList()..sort();
    }
    _postFolders = updated;
    await _persistFolders();
    notifyListeners();
  }

  Future<void> deleteFolder(String name) async {
    if (!_folders.contains(name)) return;
    _folders = _folders.where((f) => f != name).toList();
    final updated = <String, List<String>>{};
    for (final entry in _postFolders.entries) {
      final next = entry.value.where((f) => f != name).toList()..sort();
      if (next.isNotEmpty) updated[entry.key] = next;
    }
    _postFolders = updated;
    await _persistFolders();
    notifyListeners();
  }

  Future<void> setFoldersForPost(String relativePath, List<String> folders) async {
    final normalized = _normalizeRepoPath(relativePath);
    final cleaned = folders.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final next = cleaned.toList()..sort();
    final updated = Map<String, List<String>>.from(_postFolders);
    if (next.isEmpty) {
      updated.remove(normalized);
    } else {
      updated[normalized] = next;
      final allFolders = {..._folders, ...next}.toList()..sort();
      _folders = allFolders;
    }
    _postFolders = updated;
    await _persistFolders();
    notifyListeners();
  }

  Future<void> setThemePreference(ThemePreference value) async {
    _themePreference = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_preference', value.value);
    notifyListeners();
  }

  Future<void> saveToken(String token) async {
    _token = token;
    await _secureStorage.write(key: 'github_token', value: token);
    notifyListeners();
  }

  Future<void> setAutoCommit(bool value) async {
    _autoCommit = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_commit', value);
    notifyListeners();
  }

  Future<void> bootstrapRepo(String repoUrl, String token) async {
    _setBusy(true);
    try {
      final bootstrapper = RepoBootstrapper(_gitHubService);
      final config =
          await bootstrapper.bootstrap(repoUrl: repoUrl, token: token);
      _config = config;
      await saveToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('repo_config', jsonEncode(config.toJson()));
      await refreshThemeSeedColor();
    } finally {
      _setBusy(false);
    }
    notifyListeners();
  }

  String _normalizeRepoPath(String path) {
    final cleaned = path.trim();
    if (cleaned.isEmpty) return cleaned;
    return p.posix.joinAll(p.split(cleaned));
  }

  void markDirty(String relativePath) {
    _dirtyFiles.add(_normalizeRepoPath(relativePath));
  }

  Future<String?> commitFiles({
    required List<RepoFileUpdate> updates,
    required String message,
  }) async {
    if (_config == null || _token == null || _token!.isEmpty) {
      throw Exception('Missing repo config or token');
    }
    _setBusy(true);
    try {
      return await _gitHubService.commitFiles(
        owner: _config!.owner,
        repo: _config!.repo,
        branch: _config!.branch,
        token: _token!,
        message: message,
        updates: updates,
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<String?> commitDirty({String? message}) async {
    if (_config == null || _dirtyFiles.isEmpty) return null;

    final updates = <RepoFileUpdate>[];
    for (final relativePath in _dirtyFiles) {
      final file =
          File(p.joinAll([_config!.localPath, ...p.posix.split(relativePath)]));
      if (!file.existsSync()) {
        updates.add(RepoFileUpdate.delete(path: relativePath));
        continue;
      }
      final bytes = Uint8List.fromList(await file.readAsBytes());
      updates.add(RepoFileUpdate.update(path: relativePath, bytes: bytes));
    }

    final sha = await commitFiles(
      updates: updates,
      message: message ?? 'Update posts',
    );

    _dirtyFiles.clear();
    notifyListeners();
    return sha;
  }

  Future<String> readThemeHex() async {
    if (_config == null) return '#ec4899';
    final configFile = File(_config!.configPath);
    if (!configFile.existsSync()) return '#ec4899';

    final content = await configFile.readAsString();
    final match = RegExp(r'hex:\s*"([^"]+)"').firstMatch(content);
    return match?.group(1) ?? '#ec4899';
  }

  Future<void> deletePost(PostEntry entry) async {
    final repo = postRepository;
    if (repo == null) return;
    _setBusy(true);
    try {
      await repo.deletePost(entry);
      markDirty(entry.relativePath);
      await triggerWebhook(
        event: 'post.deleted',
        payload: {
          'path': entry.relativePath,
          'title': entry.title,
        },
      );
      if (_autoCommit) {
        await commitDirty(message: 'Delete ${p.basename(entry.relativePath)}');
      }
    } finally {
      _setBusy(false);
    }
    notifyListeners();
  }

  Future<PostEntry> createPost({
    required String relativePath,
    required String title,
  }) async {
    final repo = postRepository;
    if (repo == null) {
      throw Exception('Repository not initialized');
    }
    _setBusy(true);
    try {
      final entry = await repo.createPost(relativePath: relativePath, title: title);
      markDirty(entry.relativePath);
      await triggerWebhook(
        event: 'post.created',
        payload: {
          'path': entry.relativePath,
          'title': entry.title,
        },
      );
      if (_autoCommit) {
        await commitDirty(message: 'Add ${p.basename(relativePath)}');
      }
      return entry;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> savePost({
    required PostEntry entry,
    required Map<String, dynamic> frontMatter,
    required String body,
  }) async {
    final repo = postRepository;
    if (repo == null) return;
    _setBusy(true);
    try {
      await repo.savePost(entry: entry, frontMatter: frontMatter, body: body);
      markDirty(entry.relativePath);
      await triggerWebhook(
        event: 'post.updated',
        payload: {
          'path': entry.relativePath,
          'title': entry.title,
          'draft': entry.draft,
        },
      );
    } finally {
      _setBusy(false);
    }
    notifyListeners();
  }

  Future<void> refreshThemeSeedColor() async {
    final hex = await readThemeHex();
    _themeSeedColor = _parseHexColor(hex, fallback: _themeSeedColor);
    notifyListeners();
  }

  Future<SiteConfigData?> readSiteConfig() async {
    if (_config == null) return null;
    final file = File(_config!.configPath);
    if (!file.existsSync()) return null;
    return _siteConfigService.read(file);
  }

  Future<void> writeSiteConfig(SiteConfigData data) async {
    if (_config == null) return;
    final file = File(_config!.configPath);
    if (!file.existsSync()) {
      throw Exception('config.ts not found at ${_config!.configPath}');
    }
    _setBusy(true);
    try {
      await _siteConfigService.write(file, data);
      final relative = p.posix.joinAll(
        p.split(p.relative(file.path, from: _config!.localPath)),
      );
      markDirty(relative);
      await refreshThemeSeedColor();
      await triggerWebhook(
        event: 'site.updated',
        payload: {
          'path': relative,
          'title': data.title,
          'subtitle': data.subtitle,
          'description': data.description,
          'lang': data.lang,
          'themeHex': data.themeHex,
        },
      );
      if (_autoCommit) {
        await commitDirty(message: 'Update site config');
      }
    } finally {
      _setBusy(false);
    }
    notifyListeners();
  }

  Color _parseHexColor(String hex, {required Color fallback}) {
    final cleaned = hex.trim().replaceFirst('#', '');
    if (cleaned.length != 6 && cleaned.length != 8) return fallback;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    if (cleaned.length == 6) return Color(0xFF000000 | value);
    return Color(value);
  }

  Future<void> _persistFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('folders', jsonEncode(_folders));
    await prefs.setString('post_folders', jsonEncode(_postFolders));
  }

  List<String>? _decodeStringList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return null;
  }

  Map<String, List<String>>? _decodePostFolders(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final result = <String, List<String>>{};
        decoded.forEach((k, v) {
          if (k == null) return;
          if (v is List) {
            result[k.toString()] = v.map((e) => e.toString()).toList();
          }
        });
        return result;
      }
    } catch (_) {}
    return null;
  }

  List<EventRule>? _decodeEventRules(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => EventRule.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  List<EventRule>? _decodeLegacyWebhookSettings(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final enabled = decoded['enabled'] == true;
      final url = decoded['url']?.toString() ?? '';
      final secret = decoded['secret']?.toString() ?? '';
      if (!enabled || url.trim().isEmpty) return null;
      final eventsRaw = decoded['events'];
      final events = <String>[];
      if (eventsRaw is Map) {
        eventsRaw.forEach((k, v) {
          if (k == null) return;
          if (v == true) {
            events.add(k.toString());
          }
        });
      }
      final targetEvents =
          events.isEmpty ? EventRule.defaultEvents : events;
      return targetEvents
          .map(
            (event) => EventRule(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: '事件 $event',
              event: event,
              enabled: true,
              conditionText: '',
              thenAction: WebhookAction(
                url: url,
                secret: secret,
                message: '',
              ),
              elseEnabled: false,
              elseAction: const WebhookAction(),
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  String _renderTemplate(String template, Map<String, String> variables) {
    var result = template;
    variables.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}

enum ThemePreference {
  system('system'),
  light('light'),
  dark('dark');

  const ThemePreference(this.value);

  final String value;

  static ThemePreference fromString(String? value) {
    return ThemePreference.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ThemePreference.system,
    );
  }

  ThemeMode toThemeMode() {
    return switch (this) {
      ThemePreference.system => ThemeMode.system,
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
    };
  }
}

class WebhookAction {
  const WebhookAction({
    this.url = '',
    this.secret = '',
    this.message = '',
  });

  final String url;
  final String secret;
  final String message;

  bool get isValid => url.trim().isNotEmpty;

  WebhookAction copyWith({
    String? url,
    String? secret,
    String? message,
  }) {
    return WebhookAction(
      url: url ?? this.url,
      secret: secret ?? this.secret,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'secret': secret,
        'message': message,
      };

  static WebhookAction fromJson(Map<String, dynamic> json) {
    return WebhookAction(
      url: json['url']?.toString() ?? '',
      secret: json['secret']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

class EventRule {
  const EventRule({
    required this.id,
    required this.name,
    required this.event,
    required this.enabled,
    required this.conditionText,
    required this.thenAction,
    required this.elseEnabled,
    required this.elseAction,
  });

  static const defaultEvents = <String>[
    'post.created',
    'post.updated',
    'post.deleted',
    'site.updated',
  ];

  final String id;
  final String name;
  final String event;
  final bool enabled;
  final String conditionText;
  final WebhookAction thenAction;
  final bool elseEnabled;
  final WebhookAction elseAction;

  bool matches(Map<String, dynamic> payload) {
    final trimmed = conditionText.trim();
    if (trimmed.isEmpty) return true;
    final raw = jsonEncode(payload).toLowerCase();
    return raw.contains(trimmed.toLowerCase());
  }

  WebhookAction? get elseActionOrNull =>
      elseEnabled && elseAction.isValid ? elseAction : null;

  EventRule copyWith({
    String? id,
    String? name,
    String? event,
    bool? enabled,
    String? conditionText,
    WebhookAction? thenAction,
    bool? elseEnabled,
    WebhookAction? elseAction,
  }) {
    return EventRule(
      id: id ?? this.id,
      name: name ?? this.name,
      event: event ?? this.event,
      enabled: enabled ?? this.enabled,
      conditionText: conditionText ?? this.conditionText,
      thenAction: thenAction ?? this.thenAction,
      elseEnabled: elseEnabled ?? this.elseEnabled,
      elseAction: elseAction ?? this.elseAction,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'event': event,
        'enabled': enabled,
        'conditionText': conditionText,
        'thenAction': thenAction.toJson(),
        'elseEnabled': elseEnabled,
        'elseAction': elseAction.toJson(),
      };

  static EventRule fromJson(Map<String, dynamic> json) {
    return EventRule(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? '事件',
      event: json['event']?.toString() ?? defaultEvents.first,
      enabled: json['enabled'] == true,
      conditionText: json['conditionText']?.toString() ?? '',
      thenAction: json['thenAction'] is Map
          ? WebhookAction.fromJson(
              Map<String, dynamic>.from(json['thenAction'] as Map),
            )
          : const WebhookAction(),
      elseEnabled: json['elseEnabled'] == true,
      elseAction: json['elseAction'] is Map
          ? WebhookAction.fromJson(
              Map<String, dynamic>.from(json['elseAction'] as Map),
            )
          : const WebhookAction(),
    );
  }
}
