import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A vessel that drains over [duration] instead of a plain numeric
/// countdown — deliberately doesn't show the actual seconds remaining, just
/// a liquid level falling toward an empty glass with a small leak dripping
/// out the side. Calls [onExpired] once, the moment it empties. Shown to
/// the customer on a bid card: their window to accept an offer before it
/// clears and the rider is free to send a new one.
class DrainingGlassIndicator extends StatefulWidget {
  final Duration duration;
  final VoidCallback onExpired;
  final double size;

  const DrainingGlassIndicator({
    super.key,
    required this.duration,
    required this.onExpired,
    this.size = 40,
  });

  @override
  State<DrainingGlassIndicator> createState() => _DrainingGlassIndicatorState();
}

class _DrainingGlassIndicatorState extends State<DrainingGlassIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_fired) {
          _fired = true;
          widget.onExpired();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.15,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final remaining = 1.0 - _controller.value; // 1.0 = full, 0.0 = empty
          return CustomPaint(
            painter: _GlassPainter(
              remaining: remaining,
              wobblePhase: _controller.value * 40, // fast independent ripple/drip cycle
              color: remaining > 0.25 ? AppColors.primary : AppColors.accent,
            ),
          );
        },
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  final double remaining;
  final double wobblePhase;
  final Color color;

  _GlassPainter({required this.remaining, required this.wobblePhase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final glassRect = Rect.fromLTWH(size.width * 0.14, 0, size.width * 0.72, size.height * 0.82);
    final glassRRect = RRect.fromRectAndCorners(
      glassRect,
      topLeft: const Radius.circular(4),
      topRight: const Radius.circular(4),
      bottomLeft: Radius.circular(size.width * 0.14),
      bottomRight: Radius.circular(size.width * 0.14),
    );

    // Outline
    final outlinePaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRRect(glassRRect, outlinePaint);

    // Clip to the glass interior so the liquid never draws outside it.
    canvas.save();
    canvas.clipRRect(glassRRect);

    if (remaining > 0.01) {
      final liquidTopY = glassRect.top + glassRect.height * (1 - remaining);
      final wavePaint = Paint()..color = color.withValues(alpha: 0.85);
      final path = Path()..moveTo(glassRect.left, glassRect.bottom);
      path.lineTo(glassRect.left, liquidTopY);
      const waveAmplitude = 1.6;
      for (double x = 0; x <= glassRect.width; x += 4) {
        final y = liquidTopY + sin((x / glassRect.width * 2 * pi) + wobblePhase) * waveAmplitude;
        path.lineTo(glassRect.left + x, y);
      }
      path.lineTo(glassRect.right, glassRect.bottom);
      path.close();
      canvas.drawPath(path, wavePaint);
    }
    canvas.restore();

    // The "hole" — a small notch low on the glass wall the liquid leaks
    // from, plus a drip that falls and fades on a short repeating loop
    // independent of the overall drain time.
    final holeCenter = Offset(glassRect.right, glassRect.bottom - glassRect.height * 0.12);
    canvas.drawCircle(holeCenter, 2.0, Paint()..color = AppColors.muted);

    if (remaining > 0.02) {
      final dripT = (wobblePhase / 2.2) % 1.0;
      final dripY = holeCenter.dy + dripT * (size.height - holeCenter.dy);
      final dripOpacity = (1 - dripT).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(holeCenter.dx + 2, dripY),
        1.4,
        Paint()..color = color.withValues(alpha: 0.7 * dripOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlassPainter oldDelegate) =>
      oldDelegate.remaining != remaining || oldDelegate.wobblePhase != wobblePhase || oldDelegate.color != color;
}
