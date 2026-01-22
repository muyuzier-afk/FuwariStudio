import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/repo_config.dart';
import 'github_service.dart';

class RepoBootstrapper {
  RepoBootstrapper(this._gitHubService);

  final GitHubService _gitHubService;

  Future<RepoConfig> bootstrap({
    required String repoUrl,
    required String token,
  }) async {
    final repoInfo = _parseRepoUrl(repoUrl);
    final info = await _gitHubService.fetchRepoInfo(
      owner: repoInfo.owner,
      repo: repoInfo.repo,
      token: token,
    );

    final documentsDir = await getApplicationDocumentsDirectory();
    final repoDir = Directory(p.join(documentsDir.path, repoInfo.repo));

    final postsDir = Directory(p.join(repoDir.path, 'src', 'content', 'posts'));
    if (!repoDir.existsSync() || !postsDir.existsSync()) {
      if (!repoDir.existsSync()) {
        repoDir.createSync(recursive: true);
      }
      final archiveBytes = await _gitHubService.downloadArchive(
        owner: repoInfo.owner,
        repo: repoInfo.repo,
        branch: info.defaultBranch,
        token: token,
      );
      _extractArchive(archiveBytes, repoDir);
    }

    return RepoConfig(
      owner: repoInfo.owner,
      repo: repoInfo.repo,
      branch: info.defaultBranch,
      localPath: repoDir.path,
    );
  }

  RepoLocation _parseRepoUrl(String repoUrl) {
    final uri = Uri.parse(repoUrl);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) {
      throw Exception('Invalid repo URL');
    }
    final owner = segments[0];
    final repo = segments[1].replaceAll('.git', '');
    return RepoLocation(owner: owner, repo: repo);
  }

  void _extractArchive(Uint8List bytes, Directory targetDir) {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive) {
      final name = entry.name;
      final stripped = _stripTopFolder(name);
      if (stripped.isEmpty) continue;

      final outPath = p.join(targetDir.path, stripped);
      if (entry.isFile) {
        final file = File(outPath);
        file.createSync(recursive: true);
        file.writeAsBytesSync(entry.content as List<int>);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }
  }

  String _stripTopFolder(String path) {
    final parts = path.split('/');
    if (parts.length <= 1) return '';
    return parts.sublist(1).join('/');
  }
}

class RepoLocation {
  RepoLocation({required this.owner, required this.repo});

  final String owner;
  final String repo;
}
