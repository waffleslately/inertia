import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/spend_provider.dart';
import '../widgets/animated_spend_chart.dart';
import '../widgets/shuttle_loading_indicator.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class SpendScreen extends StatelessWidget {
  const SpendScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('My Spend', style: AppTypography.headline),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Consumer<SpendProvider>(
        builder: (context, spendProv, child) {
          if (spendProv.isLoading && spendProv.spendSummary == null) {
            return const ShuttleLoadingIndicator(message: 'Calculating Campus Transit Spend...');
          }

          final summary = spendProv.spendSummary;
          final total = summary?.totalSpend ?? 0.0;
          final rideCount = summary?.rideCount ?? 0;
          final pctChange = summary?.percentageChange ?? 0.0;
          final isIncrease = pctChange >= 0;

          return RefreshIndicator(
            color: AppColors.electricCyan,
            backgroundColor: AppColors.surface,
            onRefresh: () => spendProv.fetchData(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Top Highlight Card (Monthly Spend & vs Last Month)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: AppColors.darkCardGradient,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            summary?.monthName.toUpperCase() ?? 'SEPTEMBER 2026',
                            style: AppTypography.caption.copyWith(
                              letterSpacing: 1.2,
                              color: AppColors.electricCyan,
                            ),
                          ),
                          // Vs last month pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isIncrease
                                  ? AppColors.crowdHighBg
                                  : AppColors.crowdLowBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isIncrease
                                    ? AppColors.crowdHigh.withOpacity(0.4)
                                    : AppColors.crowdLow.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isIncrease
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  color: isIncrease
                                      ? AppColors.crowdHigh
                                      : AppColors.crowdLow,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${pctChange.abs()}% vs last month',
                                  style: AppTypography.badge.copyWith(
                                    color: isIncrease
                                        ? AppColors.crowdHigh
                                        : AppColors.crowdLow,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹${total.toInt()}',
                            style: AppTypography.display.copyWith(
                              fontSize: 38,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'total spend',
                            style: AppTypography.subtitle.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem('Rides Taken', '$rideCount rides'),
                          _buildStatItem('Fare Rate', '₹20 / ride'),
                          _buildStatItem('Last Month', '₹${summary?.lastMonthSpend.toInt() ?? 0}'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Animated Chart Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Daily Spend Trend', style: AppTypography.title),
                          Text('September', style: AppTypography.caption),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dynamic spend graph draws in on load',
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: 16),
                      if (summary != null && summary.dailySpend.isNotEmpty)
                        AnimatedSpendChart(data: summary.dailySpend)
                      else
                        const SizedBox(
                          height: 160,
                          child: Center(
                            child: Text(
                              'No daily spend entries recorded yet',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Recent Payments List
                Text('TRANSACTION RECEIPTS', style: AppTypography.caption),
                const SizedBox(height: 12),
                if (spendProv.history.isNotEmpty)
                  ...spendProv.history.take(6).map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.electricCyan.withOpacity(0.12),
                            ),
                            child: const Icon(
                              Icons.payment_rounded,
                              color: AppColors.electricCyan,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.routeName, style: AppTypography.title.copyWith(fontSize: 15)),
                                const SizedBox(height: 2),
                                Text('UPI: vitshuttle@okaxis • ${item.durationDisplay}', style: AppTypography.bodySmall),
                              ],
                            ),
                          ),
                          Text(
                            '₹${item.fare.toInt()}',
                            style: AppTypography.title.copyWith(
                              color: AppColors.electricCyan,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.title.copyWith(fontSize: 14)),
      ],
    );
  }
}
