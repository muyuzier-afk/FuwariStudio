import 'package:intl/intl.dart';
import 'package:yaml/yaml.dart';

class FrontMatter {
  FrontMatter({required this.data, required this.body});

  final Map<String, dynamic> data;
  final String body;
}

FrontMatter parseFrontMatter(String content) {
  if (!content.startsWith('---')) {
    return FrontMatter(data: {}, body: content);
  }

  final lines = content.split('\n');
  int endIndex = -1;
  for (int i = 1; i < lines.length; i++) {
    if (lines[i].trim() == '---') {
      endIndex = i;
      break;
    }
  }

  if (endIndex == -1) {
    return FrontMatter(data: {}, body: content);
  }

  final yamlSource = lines.sublist(1, endIndex).join('\n');
  final body = lines.sublist(endIndex + 1).join('\n');
  final yamlMap = loadYaml(yamlSource);

  final data = <String, dynamic>{};
  if (yamlMap is YamlMap) {
    for (final entry in yamlMap.entries) {
      data[entry.key.toString()] = entry.value;
    }
  }

  return FrontMatter(data: data, body: body);
}

String buildFrontMatter(Map<String, dynamic> data, String body) {
  final buffer = StringBuffer();
  buffer.writeln('---');

  void writeField(String key, String value) {
    buffer.writeln('$key: ${_formatScalar(value)}');
  }

  String formatDate(dynamic value) {
    if (value is DateTime) {
      return DateFormat('yyyy-MM-dd').format(value);
    }
    return value?.toString() ?? '';
  }

  void writeList(String key, List<dynamic> list) {
    if (list.isEmpty) {
      writeField(key, '[]');
      return;
    }
    buffer.writeln('$key:');
    for (final item in list) {
      buffer.writeln('  - ${item.toString()}');
    }
  }

  if (data['title'] != null) writeField('title', data['title'].toString());
  if (data['published'] != null) {
    writeField('published', formatDate(data['published']));
  }
  if (data['updated'] != null) {
    writeField('updated', formatDate(data['updated']));
  }
  if (data['description'] != null) {
    writeField('description', data['description'].toString());
  }
  if (data['image'] != null) {
    writeField('image', data['image'].toString());
  }
  if (data['tags'] != null && data['tags'] is List) {
    writeList('tags', data['tags'] as List<dynamic>);
  } else if (data.containsKey('tags')) {
    writeField('tags', data['tags'].toString());
  }
  if (data['category'] != null) {
    writeField('category', data['category'].toString());
  }
  if (data['draft'] != null) {
    writeField('draft', data['draft'].toString());
  }
  if (data['lang'] != null) {
    writeField('lang', data['lang'].toString());
  }

  buffer.writeln('---');
  buffer.write(body);
  if (!body.endsWith('\n')) {
    buffer.writeln();
  }

  return buffer.toString();
}

String _formatScalar(String value) {
  if (value.isEmpty) return "''";
  if (value.contains(':') || value.contains('#') || value.contains('[')) {
    final escaped = value.replaceAll('"', '\\"');
    return '"$escaped"';
  }
  return value;
}
