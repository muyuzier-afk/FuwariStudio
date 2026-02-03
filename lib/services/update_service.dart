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
    for (var i = 0; i < 4; i++) {
      final l = latestParts[i];
      final c = currentParts[i];
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  List<int> _parse(String version) {
    final trimmed = version.trim();
    if (trimmed.isEmpty) return const [0, 0, 0, 0];

    final plusParts = trimmed.split('+');
    final core = plusParts.first;
    final buildFromPlus =
        (plusParts.length > 1) ? int.tryParse(plusParts[1]) : null;

    final coreParts = core.split('.').where((e) => e.isNotEmpty).toList();
    final major = coreParts.isNotEmpty ? int.tryParse(coreParts[0]) ?? 0 : 0;
    final minor = coreParts.length > 1 ? int.tryParse(coreParts[1]) ?? 0 : 0;
    final patch = coreParts.length > 2 ? int.tryParse(coreParts[2]) ?? 0 : 0;
    final buildFromDot = coreParts.length > 3 ? int.tryParse(coreParts[3]) : null;
    final build = buildFromPlus ?? buildFromDot ?? 0;

    return [major, minor, patch, build];
  }
}
