import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ride_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class CheckInButton extends StatelessWidget {
  final VoidCallback? onExpandSheet;

  const CheckInButton({Key? key, this.onExpandSheet}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<RideProvider>(
      builder: (context, ride, child) {
        final state = ride.state;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          height: state == RideState.activeRide ? 72 : 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(state == RideState.activeRide ? 20 : 28),
            gradient: state == RideState.activeRide
                ? const LinearGradient(
                    colors: [Color(0xFF162438), Color(0xFF101B2B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : AppColors.electricGradient,
            border: Border.all(
              color: state == RideState.activeRide
                  ? AppColors.electricCyan.withOpacity(0.4)
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: state == RideState.activeRide
                    ? AppColors.cyanGlow.withOpacity(0.3)
                    : AppColors.cyanGlow,
                blurRadius: state == RideState.activeRide ? 16 : 24,
                spreadRadius: state == RideState.activeRide ? 0 : 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(state == RideState.activeRide ? 20 : 28),
              onTap: () {
                if (state == RideState.idle) {
                  ride.checkIn();
                } else if (state == RideState.activeRide) {
                  if (onExpandSheet != null) onExpandSheet!();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildContent(context, ride, state),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, RideProvider ride, RideState state) {
    switch (state) {
      case RideState.idle:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bolt_rounded,
              color: AppColors.background,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              "I'm on the Shuttle",
              style: AppTypography.title.copyWith(
                color: AppColors.background,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        );

      case RideState.checkingIn:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.background),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Snapping to Route...',
              style: AppTypography.title.copyWith(
                color: AppColors.background,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        );

      case RideState.activeRide:
      case RideState.nearDestination:
      case RideState.paymentSuccess:
        return Row(
          children: [
            // Glowing Live Pulse
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.electricCyan.withOpacity(0.15),
                border: Border.all(color: AppColors.electricCyan, width: 1.5),
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                color: AppColors.electricCyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Ride Info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.crowdLow,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'RIDING • ${ride.activeRouteName.toUpperCase()}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.electricCyan,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Next: ${ride.nextStop}',
                    style: AppTypography.title.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Tap for Details Arrow
            const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.textSecondary,
              size: 26,
            ),
          ],
        );
    }
  }
}
