import 'package:flutter/material.dart';

class CandleEasterEgg extends StatefulWidget {
  const CandleEasterEgg({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<CandleEasterEgg> createState() => _CandleEasterEggState();
}

class _CandleEasterEggState extends State<CandleEasterEgg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flicker;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _flicker = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final candle = cs.secondaryContainer;
    final wick = cs.onSecondaryContainer.withValues(alpha: 0.75);
    const flameInner = Color(0xFFFFF1B5);
    const flameOuter = Color(0xFFFF8A00);

    return Tooltip(
      message: '点亮蜡烛',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: AnimatedBuilder(
              animation: _flicker,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(42, 42),
                  painter: _CandlePainter(
                    t: _flicker.value,
                    candle: candle,
                    wick: wick,
                    flameInner: flameInner,
                    flameOuter: flameOuter,
                    glow: flameOuter.withValues(alpha: 0.33),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  const _CandlePainter({
    required this.t,
    required this.candle,
    required this.wick,
    required this.flameInner,
    required this.flameOuter,
    required this.glow,
  });

  final double t;
  final Color candle;
  final Color wick;
  final Color flameInner;
  final Color flameOuter;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final candleRect = Rect.fromLTWH(
      w * 0.28,
      h * 0.36,
      w * 0.44,
      h * 0.54,
    );
    final candleRRect =
        RRect.fromRectAndRadius(candleRect, Radius.circular(w * 0.16));
    canvas.drawRRect(candleRRect, Paint()..color = candle);

    final wickP1 = Offset(w * 0.50, h * 0.33);
    final wickP2 = Offset(w * 0.50, h * 0.40);
    canvas.drawLine(
      wickP1,
      wickP2,
      Paint()
        ..color = wick
        ..strokeWidth = w * 0.04
        ..strokeCap = StrokeCap.round,
    );

    final flameCenter = Offset(w * 0.50, h * 0.26);
    final flicker = 0.90 + 0.18 * t;
    final sway = (t - 0.5) * w * 0.035;

    canvas.save();
    canvas.translate(flameCenter.dx + sway, flameCenter.dy);
    canvas.scale(flicker, flicker);
    canvas.translate(-flameCenter.dx, -flameCenter.dy);

    final glowPaint = Paint()
      ..color = glow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: flameCenter,
        width: w * 0.26,
        height: h * 0.26,
      ),
      glowPaint,
    );

    final outer = _teardropPath(
      center: flameCenter,
      width: w * 0.20,
      height: h * 0.26,
    );
    canvas.drawPath(outer, Paint()..color = flameOuter);

    final inner = _teardropPath(
      center: flameCenter + Offset(0, h * 0.02),
      width: w * 0.12,
      height: h * 0.18,
    );
    canvas.drawPath(inner, Paint()..color = flameInner);

    canvas.restore();

    final baseShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.94),
        width: w * 0.50,
        height: h * 0.10,
      ),
      baseShadow,
    );
  }

  Path _teardropPath({
    required Offset center,
    required double width,
    required double height,
  }) {
    final top = Offset(center.dx, center.dy - height / 2);
    final bottom = Offset(center.dx, center.dy + height / 2);
    final left = Offset(center.dx - width / 2, center.dy + height * 0.08);
    final right = Offset(center.dx + width / 2, center.dy + height * 0.08);

    final c1 = Offset(center.dx - width * 0.55, center.dy - height * 0.10);
    final c2 = Offset(center.dx - width * 0.25, center.dy + height * 0.45);
    final c3 = Offset(center.dx + width * 0.25, center.dy + height * 0.45);
    final c4 = Offset(center.dx + width * 0.55, center.dy - height * 0.10);

    final path = Path()..moveTo(top.dx, top.dy);
    path.quadraticBezierTo(c1.dx, c1.dy, left.dx, left.dy);
    path.quadraticBezierTo(c2.dx, c2.dy, bottom.dx, bottom.dy);
    path.quadraticBezierTo(c3.dx, c3.dy, right.dx, right.dy);
    path.quadraticBezierTo(c4.dx, c4.dy, top.dx, top.dy);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_CandlePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.candle != candle ||
        oldDelegate.wick != wick ||
        oldDelegate.flameInner != flameInner ||
        oldDelegate.flameOuter != flameOuter ||
        oldDelegate.glow != glow;
  }
}
