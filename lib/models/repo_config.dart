import 'package:path/path.dart' as p;

class RepoConfig {
  RepoConfig({
    required this.owner,
    required this.repo,
    required this.branch,
    required this.localPath,
  });

  final String owner;
  final String repo;
  final String branch;
  final String localPath;

  String get postsPath => p.join(localPath, 'src', 'content', 'posts');
  String get assetsPath => p.join(localPath, 'src', 'content', 'assets');
  String get configPath => p.join(localPath, 'src', 'config.ts');

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'repo': repo,
        'branch': branch,
        'localPath': localPath,
      };

  static RepoConfig fromJson(Map<String, dynamic> json) {
    return RepoConfig(
      owner: json['owner'].toString(),
      repo: json['repo'].toString(),
      branch: json['branch'].toString(),
      localPath: json['localPath'].toString(),
    );
  }
}
