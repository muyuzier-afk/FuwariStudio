import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

class ImageCropScreen extends StatefulWidget {
  const ImageCropScreen({
    super.key,
    required this.imageBytes,
    this.title = '裁剪图片',
  });

  final Uint8List imageBytes;
  final String title;

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final CropController _controller = CropController();
  double? _aspectRatio;
  bool _cropping = false;

  void _save() {
    setState(() => _cropping = true);
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _cropping ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _cropping ? null : _save,
            child: _cropping
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _ratioChip(label: '自由', ratio: null),
                const SizedBox(width: 8),
                _ratioChip(label: '1:1', ratio: 1),
                const SizedBox(width: 8),
                _ratioChip(label: '4:3', ratio: 4 / 3),
                const SizedBox(width: 8),
                _ratioChip(label: '3:4', ratio: 3 / 4),
                const SizedBox(width: 8),
                _ratioChip(label: '16:9', ratio: 16 / 9),
                const SizedBox(width: 8),
                _ratioChip(label: '9:16', ratio: 9 / 16),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              color: cs.surfaceContainerHighest,
              child: Crop(
                controller: _controller,
                image: widget.imageBytes,
                aspectRatio: _aspectRatio,
                baseColor: cs.surfaceContainerHighest,
                maskColor: cs.scrim.withValues(alpha: 0.55),
                radius: 12,
                onCropped: (cropped) {
                  if (!mounted) return;
                  Navigator.pop(context, cropped);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratioChip({required String label, required double? ratio}) {
    final selected = ratio == _aspectRatio;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _cropping
          ? null
          : (_) {
              setState(() => _aspectRatio = ratio);
            },
    );
  }
}

