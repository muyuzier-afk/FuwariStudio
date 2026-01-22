import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class RepoInfo {
  RepoInfo({required this.defaultBranch});

  final String defaultBranch;
}

class RepoFileUpdate {
  RepoFileUpdate.update({required this.path, required this.bytes})
      : delete = false;

  RepoFileUpdate.delete({required this.path})
      : delete = true,
        bytes = null;

  final String path;
  final bool delete;
  final Uint8List? bytes;
}

class GitHubService {
  GitHubService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 20);

  Future<http.Response> _get(Uri uri, {String? token}) async {
    try {
      return await _client
          .get(uri, headers: _headers(token))
          .timeout(_timeout);
    } catch (e) {
      throw Exception('Network error while calling GitHub API: $e');
    }
  }

  Future<http.Response> _post(Uri uri,
      {required String token, required String body}) async {
    try {
      return await _client
          .post(uri, headers: _headers(token), body: body)
          .timeout(_timeout);
    } catch (e) {
      throw Exception('Network error while calling GitHub API: $e');
    }
  }

  Future<http.Response> _patch(Uri uri,
      {required String token, required String body}) async {
    try {
      return await _client
          .patch(uri, headers: _headers(token), body: body)
          .timeout(_timeout);
    } catch (e) {
      throw Exception('Network error while calling GitHub API: $e');
    }
  }

  Never _throwGitHubError(http.Response response) {
    String? message;
    String? documentationUrl;
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) {
        message = parsed['message']?.toString();
        documentationUrl = parsed['documentation_url']?.toString();
      }
    } catch (_) {}

    final rateRemaining = response.headers['x-ratelimit-remaining'];
    final rateReset = response.headers['x-ratelimit-reset'];
    final rateLimit = (rateRemaining != null || rateReset != null)
        ? ' rateLimitRemaining=$rateRemaining rateLimitReset=$rateReset'
        : '';

    final msg = (message == null || message.isEmpty) ? '' : ' message=$message';
    final doc = (documentationUrl == null || documentationUrl.isEmpty)
        ? ''
        : ' doc=$documentationUrl';

    if (response.statusCode == 401) {
      throw Exception(
        'GitHub API error: 401（Bad credentials）$msg。请检查 Token 是否粘贴完整、未过期/未撤销，并且 Token 类型匹配（Fine-grained 以 github_pat_ 开头；Classic 以 ghp_ 开头）。$doc',
      );
    }

    throw Exception(
        'GitHub API error: ${response.statusCode}$rateLimit$msg$doc');
  }

  Future<RepoInfo> fetchRepoInfo({
    required String owner,
    required String repo,
    String? token,
  }) async {
    final uri = Uri.https('api.github.com', '/repos/$owner/$repo');
    final response = await _get(uri, token: token);
    if (response.statusCode != 200) {
      _throwGitHubError(response);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return RepoInfo(
        defaultBranch: json['default_branch']?.toString() ?? 'main');
  }

  Future<Uint8List> downloadArchive({
    required String owner,
    required String repo,
    required String branch,
    String? token,
  }) async {
    final uri =
        Uri.https('api.github.com', '/repos/$owner/$repo/zipball/$branch');
    final response = await _get(uri, token: token);
    if (response.statusCode != 200) {
      _throwGitHubError(response);
    }
    return response.bodyBytes;
  }

  Future<String?> commitFiles({
    required String owner,
    required String repo,
    required String branch,
    required String token,
    required String message,
    required List<RepoFileUpdate> updates,
  }) async {
    if (updates.isEmpty) return null;

    final ref = await _getJson(
      Uri.https('api.github.com', '/repos/$owner/$repo/git/ref/heads/$branch'),
      token: token,
    );
    final headSha = (ref['object'] as Map<String, dynamic>)['sha'] as String;

    final commit = await _getJson(
      Uri.https('api.github.com', '/repos/$owner/$repo/git/commits/$headSha'),
      token: token,
    );
    final baseTreeSha =
        (commit['tree'] as Map<String, dynamic>)['sha'] as String;

    final treeItems = <Map<String, dynamic>>[];
    for (final update in updates) {
      if (update.delete) {
        treeItems.add({
          'path': update.path,
          'mode': '100644',
          'type': 'blob',
          'sha': null,
        });
        continue;
      }

      final blobSha = await _createBlob(
        owner: owner,
        repo: repo,
        token: token,
        bytes: update.bytes!,
      );
      treeItems.add({
        'path': update.path,
        'mode': '100644',
        'type': 'blob',
        'sha': blobSha,
      });
    }

    final newTree = await _postJson(
      Uri.https('api.github.com', '/repos/$owner/$repo/git/trees'),
      token: token,
      body: {
        'base_tree': baseTreeSha,
        'tree': treeItems,
      },
    );

    final newCommit = await _postJson(
      Uri.https('api.github.com', '/repos/$owner/$repo/git/commits'),
      token: token,
      body: {
        'message': message,
        'tree': newTree['sha'],
        'parents': [headSha],
      },
    );
    final newCommitSha = newCommit['sha'] as String;

    await _patchJson(
      Uri.https('api.github.com', '/repos/$owner/$repo/git/refs/heads/$branch'),
      token: token,
      body: {
        'sha': newCommitSha,
        'force': false,
      },
    );

    final updatedRef = await _getJson(
      Uri.https('api.github.com', '/repos/$owner/$repo/git/ref/heads/$branch'),
      token: token,
    );
    final updatedHead =
        (updatedRef['object'] as Map<String, dynamic>)['sha'] as String;
    if (updatedHead != newCommitSha) {
      throw Exception(
          'GitHub API error: ref update mismatch (expected=$newCommitSha actual=$updatedHead)');
    }

    return newCommitSha;
  }

  Future<String> _createBlob({
    required String owner,
    required String repo,
    required String token,
    required Uint8List bytes,
  }) async {
    final json = await _postJson(
      Uri.https('api.github.com', '/repos/$owner/$repo/git/blobs'),
      token: token,
      body: {
        'content': base64Encode(bytes),
        'encoding': 'base64',
      },
    );
    return json['sha'] as String;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, {String? token}) async {
    final response = await _get(uri, token: token);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwGitHubError(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final response =
        await _post(uri, token: token, body: jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwGitHubError(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _patchJson(
    Uri uri, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final response =
        await _patch(uri, token: token, body: jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwGitHubError(response);
    }
  }

  Map<String, String> _headers(String? token) {
    final headers = <String, String>{
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'fuwari-post-studio',
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (token != null && token.isNotEmpty) {
      final trimmed = token.trim();
      final isFineGrained = trimmed.startsWith('github_pat_');
      headers['Authorization'] =
          isFineGrained ? 'Bearer $trimmed' : 'token $trimmed';
    }
    return headers;
  }
}
