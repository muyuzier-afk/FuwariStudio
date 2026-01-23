import 'dart:convert';

import 'package:http/http.dart' as http;

class UpdateInfo {
  UpdateInfo({required this.version, required this.url});

  final String version;
  final String url;
}

class UpdateService {
  static const _owner = 'muyuzier-afk';
  static const _repo = 'FuwariStudio';
  static const Duration _timeout = Duration(seconds: 12);

  Future<UpdateInfo?> fetchLatestRelease() async {
    final uri = Uri.https('api.github.com', '/repos/$_owner/$_repo/releases/latest');
    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawTag = data['tag_name']?.toString() ?? '';
      final url = data['html_url']?.toString() ?? '';
      final version = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;
      if (version.isEmpty || url.isEmpty) return null;
      return UpdateInfo(version: version, url: url);
    } catch (_) {
      return null;
    }
  }

  bool isNewerVersion(String latest, String current) {
    final latestParts = _parse(latest);
    final currentParts = _parse(current);
    for (var i = 0; i < 3; i++) {
      final l = latestParts[i];
      final c = currentParts[i];
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  List<int> _parse(String version) {
    final core = version.split('+').first;
    final parts = core.split('.');
    final nums = <int>[];
    for (var i = 0; i < 3; i++) {
      if (i < parts.length) {
        nums.add(int.tryParse(parts[i]) ?? 0);
      } else {
        nums.add(0);
      }
    }
    return nums;
  }
}

