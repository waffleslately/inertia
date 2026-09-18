import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/spend_summary.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class AnimatedSpendChart extends StatefulWidget {
  final List<DailySpendPoint> data;

  const AnimatedSpendChart({Key? key, required this.data}) : super(key: key);

  @override
  State<AnimatedSpendChart> createState() => _AnimatedSpendChartState();
}

class _AnimatedSpendChartState extends State<AnimatedSpendChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _progressAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedSpendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 180),
          painter: SpendChartPainter(
            data: widget.data,
            animationProgress: _progressAnimation.value,
          ),
        );
      },
    );
  }
}

class SpendChartPainter extends CustomPainter {
  final List<DailySpendPoint> data;
  final double animationProgress;

  SpendChartPainter({
    required this.data,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const padLeft = 24.0;
    const padRight = 16.0;
    const padBottom = 28.0;
    const padTop = 16.0;

    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;

    // Find max value
    double maxVal = 40.0;
    for (var d in data) {
      if (d.amount > maxVal) maxVal = d.amount;
    }
    maxVal = (maxVal * 1.25); // headroom

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = AppColors.border.withOpacity(0.4)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 3; i++) {
      final y = padTop + (chartH * (i / 3));
      canvas.drawLine(
        Offset(padLeft, y),
        Offset(size.width - padRight, y),
        gridPaint,
      );

      // Y-axis label
      final val = (maxVal * (1.0 - (i / 3))).toInt();
      final textPainter = TextPainter(
        text: TextSpan(
          text: '₹$val',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            fontFamily: 'Inter',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    // Points calculation
    final points = <Offset>[];
    final barW = math.min(18.0, chartW / (data.length * 1.6));

    for (int i = 0; i < data.length; i++) {
      final x = padLeft + (chartW * (i / math.max(data.length - 1, 1)));
      final targetY = padTop + chartH - ((data[i].amount / maxVal) * chartH);

      // Progress animation draws in
      final animatedY = padTop + chartH - ((padTop + chartH - targetY) * animationProgress);
      points.add(Offset(x, animatedY));

      // Draw vertical bars with rounded caps
      final barTop = animatedY;
      final barBottom = padTop + chartH;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x - barW / 2, barTop, x + barW / 2, barBottom),
        const Radius.circular(4),
      );

      final barPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.electricCyan.withOpacity(0.8),
            AppColors.electricBlue.withOpacity(0.2),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(x - barW / 2, barTop, barW, barBottom - barTop));

      canvas.drawRRect(barRect, barPaint);

      // X-axis Day labels
      if (i % 2 == 0 || i == data.length - 1) {
        final dateStr = data[i].date.split('-').last; // e.g. "15"
        final xTextPainter = TextPainter(
          text: TextSpan(
            text: dateStr,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontFamily: 'Inter',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        xTextPainter.paint(
          canvas,
          Offset(x - xTextPainter.width / 2, padTop + chartH + 8),
        );
      }
    }

    // Draw Smooth Trend Line across points
    if (points.length > 1) {
      final linePath = Path();
      linePath.moveTo(points[0].dx, points[0].dy);

      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final midX = (prev.dx + curr.dx) / 2;
        linePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      }

      // Glowing underlay
      final lineGlow = Paint()
        ..color = AppColors.electricCyan.withOpacity(0.35)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(linePath, lineGlow);

      // Main line
      final lineCore = Paint()
        ..color = AppColors.electricCyan
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(linePath, lineCore);

      // Dots on top of bars
      for (var pt in points) {
        final dotGlow = Paint()
          ..color = AppColors.cyanGlow
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, 5.0, dotGlow);

        final dotCore = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, 2.5, dotCore);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpendChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.data != data;
  }
}
