import 'dart:math';

import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    required this.child,
    this.emit = false,
    this.duration = const Duration(seconds: 3),
  });

  final Widget child;
  final bool emit;
  final Duration duration;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();
  bool _wasEmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.emit && !_wasEmitting) {
      _startEmission();
    }
    _wasEmitting = widget.emit;
  }

  void _startEmission() {
    final count = 80 + _random.nextInt(40);
    for (int i = 0; i < count; i++) {
      Future.delayed(Duration(milliseconds: _random.nextInt(500)), () {
        if (mounted) {
          setState(() {
            _particles.add(_ConfettiParticle(_random));
          });
        }
      });
    }

    Future.delayed(widget.duration + const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _particles.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_particles.isNotEmpty)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ConfettiPainter(_particles),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle(Random random)
      : x = random.nextDouble(),
        y = -0.1,
        velocityY = 0.008 + random.nextDouble() * 0.012,
        velocityX = (random.nextDouble() - 0.5) * 0.02,
        rotation = random.nextDouble() * 2 * pi,
        rotationSpeed = (random.nextDouble() - 0.5) * 0.3,
        color = _randomColor(random),
        width = 6 + random.nextDouble() * 6,
        height = 3 + random.nextDouble() * 5;

  double x;
  double y;
  double velocityY;
  double velocityX;
  double rotation;
  double rotationSpeed;
  final Color color;
  final double width;
  final double height;
  bool get isAlive => y < 1.2;

  void update() {
    y += velocityY;
    x += velocityX;
    velocityY += 0.0003;
    rotation += rotationSpeed;
  }
}

Color _randomColor(Random random) {
  const colors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFFF8E53),
    Color(0xFFE056FD),
    Color(0xFFF8B500),
    Color(0xFF00D2D3),
    Color(0xFFFF85A2),
    Color(0xFF7BED9F),
  ];
  return colors[random.nextInt(colors.length)];
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles);

  final List<_ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      if (!particle.isAlive) continue;

      particle.update();

      final paint = Paint()..color = particle.color;
      final rect = Rect.fromCenter(
        center: Offset(particle.x * size.width, particle.y * size.height),
        width: particle.width,
        height: particle.height,
      );

      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(particle.rotation);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      canvas.drawRect(rect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
