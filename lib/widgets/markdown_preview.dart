import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({
    super.key,
    required this.markdown,
    required this.basePath,
    required this.themeHex,
  });

  final String markdown;
  final String basePath;
  final String themeHex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const textColor = Color(0xFF0F172A);
    const fontFallback = <String>[
      'MiSans',
      'Noto Sans SC',
      'PingFang SC',
      'Microsoft YaHei',
      'Segoe UI',
      'Roboto',
    ];

    final baseText = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontFamily: 'MiSans',
      fontFamilyFallback: fontFallback,
      color: textColor,
      height: 1.6,
    );

    final style = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: baseText,
      a: baseText.copyWith(color: const Color(0xFF2563EB)),
      strong: baseText.copyWith(fontWeight: FontWeight.w700),
      em: baseText.copyWith(fontStyle: FontStyle.italic),
      h1: theme.textTheme.headlineMedium?.copyWith(
        fontFamily: 'MiSans',
        fontFamilyFallback: fontFallback,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
      h2: theme.textTheme.headlineSmall?.copyWith(
        fontFamily: 'MiSans',
        fontFamilyFallback: fontFallback,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
      h3: theme.textTheme.titleLarge?.copyWith(
        fontFamily: 'MiSans',
        fontFamilyFallback: fontFallback,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
      listBullet: baseText,
      code: baseText.copyWith(
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: const [
          'JetBrains Mono',
          'Cascadia Mono',
          'Consolas',
          'monospace'
        ],
        fontSize: 13,
        height: 1.55,
        color: textColor,
        backgroundColor: const Color(0xFFF1F5F9),
      ),
      codeblockPadding: const EdgeInsets.all(14),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      blockquotePadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      blockquoteDecoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
    );

    return Container(
      color: Colors.white,
      child: Markdown(
        data: markdown,
        selectable: false,
        padding: const EdgeInsets.all(18),
        styleSheet: style,
        sizedImageBuilder: (config) {
          final resolved = _resolveUri(config.uri);
          if (resolved == null) {
            return _missingImage(config.alt);
          }
          if (resolved.scheme == 'http' || resolved.scheme == 'https') {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                resolved.toString(),
                width: config.width,
                height: config.height,
                fit: BoxFit.contain,
              ),
            );
          }
          if (resolved.scheme == 'file' || resolved.scheme.isEmpty) {
            final file = File.fromUri(resolved);
            if (!file.existsSync()) return _missingImage(config.alt);
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file,
                width: config.width,
                height: config.height,
                fit: BoxFit.contain,
              ),
            );
          }
          return _missingImage(config.alt);
        },
        onTapLink: (text, href, title) {
          // Keep it simple: let users copy links from context menu / selection.
        },
      ),
    );
  }

  Uri? _resolveUri(Uri uri) {
    if (uri.scheme == 'http' ||
        uri.scheme == 'https' ||
        uri.scheme == 'file' ||
        uri.scheme == 'data') {
      return uri;
    }
    final raw = uri.toString();
    if (raw.isEmpty) return null;
    if (raw.startsWith('/')) return Uri.file(raw);
    if (basePath.isEmpty) return Uri.file(raw);
    final base = Uri.file(basePath.endsWith(Platform.pathSeparator)
        ? basePath
        : '$basePath${Platform.pathSeparator}');
    return base.resolveUri(uri);
  }

  Widget _missingImage(String? alt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined,
              size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(
            alt?.isNotEmpty == true ? alt! : '图片无法加载',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
