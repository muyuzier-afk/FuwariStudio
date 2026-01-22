import 'dart:io';

import '../models/front_matter.dart';

class PostEntry {
  PostEntry({
    required this.file,
    required this.relativePath,
    required this.frontMatter,
  });

  final File file;
  final String relativePath;
  final FrontMatter frontMatter;

  String get title =>
      (frontMatter.data['title'] ?? file.uri.pathSegments.last).toString();

  DateTime? get published {
    final value = frontMatter.data['published'];
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value != null) {
      return DateTime.tryParse(value.toString());
    }
    return null;
  }

  bool get draft {
    final value = frontMatter.data['draft'];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  String get body => frontMatter.body;
}
