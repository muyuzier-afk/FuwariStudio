import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/repo_config.dart';
import 'services/github_service.dart';
import 'services/post_repository.dart';
import 'services/repo_bootstrapper.dart';

class AppState extends ChangeNotifier {
  AppState()
      : _secureStorage = const FlutterSecureStorage(),
        _gitHubService = GitHubService();

  final FlutterSecureStorage _secureStorage;
  final GitHubService _gitHubService;

  RepoConfig? _config;
  String? _token;
  bool _autoCommit = true;
  bool _busy = false;
  final Set<String> _dirtyFiles = {};
  ThemePreference _themePreference = ThemePreference.system;
  Color _themeSeedColor = const Color(0xFFEC4899);

  RepoConfig? get config => _config;
  String? get token => _token;
  bool get autoCommit => _autoCommit;
  bool get isBusy => _busy;
  bool get hasRepo => _config != null;
  ThemeMode get themeMode => _themePreference.toThemeMode();
  ThemePreference get themePreference => _themePreference;
  Color get themeSeedColor => _themeSeedColor;

  PostRepository? get postRepository =>
      _config == null ? null : PostRepository(_config!);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('repo_config');
    _autoCommit = prefs.getBool('auto_commit') ?? true;
    _themePreference = ThemePreference.fromString(
      prefs.getString('theme_preference'),
    );
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

  Future<void> refreshThemeSeedColor() async {
    final hex = await readThemeHex();
    _themeSeedColor = _parseHexColor(hex, fallback: _themeSeedColor);
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
