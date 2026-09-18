import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class ShuttleLoadingIndicator extends StatefulWidget {
  final String message;

  const ShuttleLoadingIndicator({
    Key? key,
    this.message = 'Locking onto Campus Shuttles...',
  }) : super(key: key);

  @override
  State<ShuttleLoadingIndicator> createState() => _ShuttleLoadingIndicatorState();
}

class _ShuttleLoadingIndicatorState extends State<ShuttleLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shuttleBounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _shuttleBounce = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glowing pulsing ring
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.electricCyan.withOpacity(0.12),
                        border: Border.all(
                          color: AppColors.electricCyan.withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.electricCyan.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Shuttle icon bouncing
                  Transform.translate(
                    offset: Offset(0, _shuttleBounce.value),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.electricGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyanGlow,
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_bus_rounded,
                          color: AppColors.background,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            widget.message,
            style: AppTypography.subtitle.copyWith(
              color: AppColors.electricCyan,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Aggregating co-moving student GPS pings',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
