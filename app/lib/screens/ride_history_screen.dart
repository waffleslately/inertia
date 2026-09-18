import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/spend_provider.dart';
import '../widgets/shuttle_loading_indicator.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Ride History', style: AppTypography.headline),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Consumer<SpendProvider>(
        builder: (context, spendProv, child) {
          if (spendProv.isLoading && spendProv.history.isEmpty) {
            return const ShuttleLoadingIndicator(message: 'Retrieving Trip Logs...');
          }

          if (spendProv.history.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_toggle_off_rounded,
                    color: AppColors.textMuted,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text('No Campus Rides Recorded Yet', style: AppTypography.title),
                  const SizedBox(height: 6),
                  Text(
                    'Hop on a shuttle and check in to start tracking!',
                    style: AppTypography.subtitle,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.electricCyan,
            backgroundColor: AppColors.surface,
            onRefresh: () => spendProv.fetchData(),
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: spendProv.history.length,
              itemBuilder: (context, index) {
                final item = spendProv.history[index];
                final date = DateTime.fromMillisecondsSinceEpoch(
                    (item.startTime * 1000).toInt());
                final formattedDate =
                    DateFormat('MMM d, yyyy • hh:mm a').format(date);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Route Line Indicator
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.routeId == 'route_1'
                              ? AppColors.electricCyan.withOpacity(0.15)
                              : AppColors.electricBlue.withOpacity(0.15),
                          border: Border.all(
                            color: item.routeId == 'route_1'
                                ? AppColors.electricCyan
                                : AppColors.electricBlue,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.directions_bus_rounded,
                          color: item.routeId == 'route_1'
                              ? AppColors.electricCyan
                              : AppColors.electricBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Trip Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.routeName,
                              style: AppTypography.title.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              formattedDate,
                              style: AppTypography.caption,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.durationDisplay,
                                    style: AppTypography.badge.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.paid
                                        ? AppColors.crowdLowBg
                                        : AppColors.crowdMediumBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.paid ? 'PAID ₹20' : 'UNPAID',
                                    style: AppTypography.badge.copyWith(
                                      color: item.paid
                                          ? AppColors.crowdLow
                                          : AppColors.crowdMedium,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Fare
                      Text(
                        '₹${item.fare.toInt()}',
                        style: AppTypography.headline.copyWith(
                          fontSize: 18,
                          color: AppColors.electricCyan,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
