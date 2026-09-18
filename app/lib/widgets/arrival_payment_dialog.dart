import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ride_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class ArrivalPaymentDialog extends StatefulWidget {
  const ArrivalPaymentDialog({Key? key}) : super(key: key);

  @override
  State<ArrivalPaymentDialog> createState() => _ArrivalPaymentDialogState();
}

class _ArrivalPaymentDialogState extends State<ArrivalPaymentDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RideProvider>(
      builder: (context, ride, child) {
        final isSuccess = ride.state == RideState.paymentSuccess;

        return ScaleTransition(
          scale: _scaleAnimation,
          child: Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: isSuccess
                  ? _buildSuccessView(context, ride)
                  : _buildPaymentPromptView(context, ride),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentPromptView(BuildContext context, RideProvider ride) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Arrival Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.electricCyan.withOpacity(0.12),
            border: Border.all(color: AppColors.electricCyan, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cyanGlow,
                blurRadius: 20,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.pin_drop_rounded,
              color: AppColors.electricCyan,
              size: 32,
            ),
          ),
        ),

        const SizedBox(height: 18),

        Text(
          'Approaching Destination',
          style: AppTypography.caption.copyWith(
            color: AppColors.electricCyan,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ride.nextStop,
          style: AppTypography.headline.copyWith(fontSize: 20),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 20),

        // Fare Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shuttle Fare', style: AppTypography.caption),
                  const SizedBox(height: 2),
                  Text('VPA: ${ride.upiVpa}', style: AppTypography.bodySmall),
                ],
              ),
              Text(
                '₹${ride.fare.toInt()}',
                style: AppTypography.display.copyWith(
                  color: AppColors.electricCyan,
                  fontSize: 28,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Pay via UPI Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.electricCyan,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: () {
              ride.launchUpiPayment(context: context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Pay ₹${ride.fare.toInt()} via UPI',
                  style: AppTypography.title.copyWith(
                    color: AppColors.background,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Dismiss / Later Button
        TextButton(
          onPressed: () {
            ride.dismissArrivalModal();
          },
          child: Text(
            'Dismiss for Now',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(BuildContext context, RideProvider ride) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated Success Ring & Checkmark
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.crowdLow.withOpacity(0.15),
            border: Border.all(color: AppColors.crowdLow, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.crowdLow.withOpacity(0.4),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.check_rounded,
              color: AppColors.crowdLow,
              size: 40,
            ),
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Payment Confirmed!',
          style: AppTypography.headline.copyWith(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          '₹${ride.fare.toInt()} paid to ${ride.upiVpa}',
          style: AppTypography.subtitle,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Ride recorded in My Spend ledger',
            style: AppTypography.caption.copyWith(color: AppColors.crowdLow),
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              ride.dismissArrivalModal();
            },
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}
