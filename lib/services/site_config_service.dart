import 'dart:io';

class SiteConfigData {
  SiteConfigData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.keywords,
    required this.lang,
    required this.themeHex,
  });

  final String title;
  final String subtitle;
  final String description;
  final List<String> keywords;
  final String lang;
  final String themeHex;

  SiteConfigData copyWith({
    String? title,
    String? subtitle,
    String? description,
    List<String>? keywords,
    String? lang,
    String? themeHex,
  }) {
    return SiteConfigData(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      keywords: keywords ?? this.keywords,
      lang: lang ?? this.lang,
      themeHex: themeHex ?? this.themeHex,
    );
  }
}

class SiteConfigService {
  Future<SiteConfigData> read(File file) async {
    final content = await file.readAsString();
    return parse(content);
  }

  SiteConfigData parse(String content) {
    final block = _extractSiteConfigBlock(content);
    String pickString(String key, {String fallback = ''}) {
      final re = RegExp(
        '$key\\s*:\\s*(["\'])(.*?)\\1',
        dotAll: true,
      );
      final m = re.firstMatch(block);
      return m?.group(2) ?? fallback;
    }

    List<String> pickKeywords() {
      final re = RegExp(r'keywords\s*:\s*\[(.*?)\]', dotAll: true);
      final m = re.firstMatch(block);
      final raw = m?.group(1) ?? '';
      final items = <String>[];
      final strRe = RegExp('(["\'])(.*?)\\1', dotAll: true);
      for (final sm in strRe.allMatches(raw)) {
        final v = (sm.group(2) ?? '').trim();
        if (v.isNotEmpty) items.add(v);
      }
      return items;
    }

    String pickThemeHex() {
      final re = RegExp(r'themeColor\s*:\s*\{(.*?)\}', dotAll: true);
      final m = re.firstMatch(block);
      final inner = m?.group(1) ?? '';
      final hexRe = RegExp('hex\\s*:\\s*(["\'])(.*?)\\1', dotAll: true);
      return hexRe.firstMatch(inner)?.group(2) ?? '#ec4899';
    }

    return SiteConfigData(
      title: pickString('title'),
      subtitle: pickString('subtitle'),
      description: pickString('description'),
      keywords: pickKeywords(),
      lang: pickString('lang', fallback: 'zh_CN'),
      themeHex: pickThemeHex(),
    );
  }

  Future<void> write(File file, SiteConfigData data) async {
    final content = await file.readAsString();
    final updated = update(content, data);
    await file.writeAsString(updated);
  }

  String update(String content, SiteConfigData data) {
    final block = _extractSiteConfigBlock(content);
    var updated = block;
    updated = _replaceStringField(updated, 'title', data.title);
    updated = _replaceStringField(updated, 'subtitle', data.subtitle);
    updated = _replaceStringField(updated, 'description', data.description);
    updated = _replaceStringField(updated, 'lang', data.lang);
    updated = _replaceKeywords(updated, data.keywords);
    updated = _replaceThemeHex(updated, data.themeHex);

    return content.replaceFirst(block, updated);
  }

  String _extractSiteConfigBlock(String content) {
    final start = content.indexOf('export const siteConfig');
    if (start < 0) throw Exception('siteConfig not found');
    final braceStart = content.indexOf('{', start);
    if (braceStart < 0) throw Exception('siteConfig block not found');

    var depth = 0;
    for (var i = braceStart; i < content.length; i++) {
      final ch = content[i];
      if (ch == '{') depth++;
      if (ch == '}') depth--;
      if (depth == 0) {
        // include trailing ';' if present
        var end = i + 1;
        while (end < content.length && (content[end] == ';' || content[end] == '\r' || content[end] == '\n' || content[end] == ' ')) {
          if (content[end] == ';') {
            end++;
            break;
          }
          end++;
        }
        return content.substring(start, end);
      }
    }
    throw Exception('siteConfig block not closed');
  }

  String _replaceStringField(String block, String key, String value) {
    final re = RegExp('(^\\s*$key\\s*:\\s*)(["\'])(.*?)(\\2)(\\s*,?)',
        multiLine: true);
    if (!re.hasMatch(block)) return block;
    return block.replaceFirstMapped(re, (m) {
      final prefix = m.group(1) ?? '';
      final quote = m.group(2) ?? '"';
      final suffix = m.group(5) ?? '';
      final escaped = value.replaceAll('\\', '\\\\').replaceAll(quote, '\\$quote');
      return '$prefix$quote$escaped$quote$suffix';
    });
  }

  String _replaceKeywords(String block, List<String> keywords) {
    final re = RegExp(r'(^\s*keywords\s*:\s*)\[(.*?)\](\s*,?)', multiLine: true, dotAll: true);
    if (!re.hasMatch(block)) return block;
    final formatted = keywords.map((k) => '"${k.replaceAll('"', '\\"')}"').join(', ');
    return block.replaceFirstMapped(re, (m) {
      final prefix = m.group(1) ?? '';
      final suffix = m.group(3) ?? '';
      return '$prefix[$formatted]$suffix';
    });
  }

  String _replaceThemeHex(String block, String themeHex) {
    final re = RegExp(r'(themeColor\s*:\s*\{)(.*?)(\}\s*,?)', dotAll: true);
    final m = re.firstMatch(block);
    if (m == null) return block;
    final inner = m.group(2) ?? '';
    final hexRe = RegExp(
      '(^\\s*hex\\s*:\\s*)(["\'])(.*?)(\\2)(\\s*,?)',
      multiLine: true,
    );
    if (!hexRe.hasMatch(inner)) return block;
    final nextInner = inner.replaceFirstMapped(hexRe, (hm) {
      final prefix = hm.group(1) ?? '';
      final quote = hm.group(2) ?? '"';
      final suffix = hm.group(5) ?? '';
      final escaped = themeHex.replaceAll('\\', '\\\\').replaceAll(quote, '\\$quote');
      return '$prefix$quote$escaped$quote$suffix';
    });
    return block.replaceRange(m.start, m.end, '${m.group(1)}$nextInner${m.group(3)}');
  }
}
