import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/front_matter.dart';
import '../models/post_entry.dart';
import '../models/repo_config.dart';

class PostRepository {
  PostRepository(this.config);

  final RepoConfig config;

  Future<List<PostEntry>> listPosts() async {
    final postsDir = Directory(config.postsPath);
    if (!postsDir.existsSync()) {
      return [];
    }

    final files =
        postsDir.listSync(recursive: true).whereType<File>().where((file) {
      final ext = p.extension(file.path).toLowerCase();
      return ext == '.md' || ext == '.mdx';
    }).toList();

    final entries = <PostEntry>[];
    for (final file in files) {
      entries.add(await loadPost(file));
    }

    entries.sort((a, b) {
      final aDate = a.published ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.published ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return entries;
  }

  Future<PostEntry> loadPost(File file) async {
    final content = await file.readAsString();
    final frontMatter = parseFrontMatter(content);
    final relativePath =
        p.posix.joinAll(p.split(p.relative(file.path, from: config.localPath)));
    return PostEntry(
      file: file,
      relativePath: relativePath,
      frontMatter: frontMatter,
    );
  }

  Future<PostEntry> createPost({
    required String relativePath,
    required String title,
  }) async {
    final filePath =
        p.joinAll([config.localPath, ...p.posix.split(relativePath)]);
    final file = File(filePath);
    if (file.existsSync()) {
      throw Exception('File already exists');
    }

    file.createSync(recursive: true);
    final content = buildFrontMatter({
      'title': title,
      'published': DateTime.now(),
      'description': '',
      'image': '',
      'tags': <String>[],
      'category': '',
      'draft': false,
      'lang': '',
    }, '');

    await file.writeAsString(content);
    return loadPost(file);
  }

  Future<void> savePost({
    required PostEntry entry,
    required Map<String, dynamic> frontMatter,
    required String body,
  }) async {
    final content = buildFrontMatter(frontMatter, body);
    await entry.file.writeAsString(content);
  }

  Future<void> deletePost(PostEntry entry) async {
    if (entry.file.existsSync()) {
      await entry.file.delete();
    }
  }
}
