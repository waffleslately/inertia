import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ride_provider.dart';
import '../providers/shuttle_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class RideDetailsSheet extends StatelessWidget {
  const RideDetailsSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<RideProvider, ShuttleProvider>(
      builder: (context, ride, shuttleProv, child) {
        final activeRoute = shuttleProv.routes.firstWhere(
          (r) => r.id == ride.activeRouteId,
          orElse: () => shuttleProv.routes.isNotEmpty
              ? shuttleProv.routes.first
              : null as dynamic,
        );

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 32,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Route Info & Fare
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.electricCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.electricCyan.withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                activeRoute?.shortName ?? 'ROUTE 1',
                                style: AppTypography.badge.copyWith(
                                  color: AppColors.electricCyan,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              activeRoute?.name ?? 'VIT Main Loop',
                              style: AppTypography.headline.copyWith(fontSize: 18),
                            ),
                          ],
                        ),
                        // Fare Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('FARE', style: AppTypography.caption),
                              Text(
                                '₹${ride.fare.toInt()}',
                                style: AppTypography.headline.copyWith(
                                  color: AppColors.electricCyan,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Metrics Strip (Crowd, Speed, GPS Sync)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricItem(
                            icon: Icons.people_alt_rounded,
                            label: 'Crowd Level',
                            value: 'Moderate (5)',
                            color: AppColors.crowdMedium,
                          ),
                          Container(width: 1, height: 30, color: AppColors.border),
                          _buildMetricItem(
                            icon: Icons.speed_rounded,
                            label: 'Avg Speed',
                            value: '18 km/h',
                            color: AppColors.textPrimary,
                          ),
                          Container(width: 1, height: 30, color: AppColors.border),
                          _buildMetricItem(
                            icon: Icons.gps_fixed_rounded,
                            label: 'Battery GPS',
                            value: 'Adaptive',
                            color: AppColors.electricCyan,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Stop Timeline Preview
                    Text('CAMPUS ROUTE STOPS', style: AppTypography.caption),
                    const SizedBox(height: 10),
                    if (activeRoute != null)
                      Column(
                        children: activeRoute.stops.map<Widget>((stop) {
                          final isNext = stop.name == ride.nextStop;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isNext
                                        ? AppColors.electricCyan
                                        : AppColors.border,
                                    boxShadow: isNext
                                        ? [
                                            const BoxShadow(
                                              color: AppColors.electricCyan,
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    stop.name,
                                    style: AppTypography.body.copyWith(
                                      fontWeight: isNext
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isNext
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                if (isNext)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.electricCyan.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Next Stop',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.electricCyan,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 22),

                    // Actions Row: Simulate Near Stop arrival / End Ride
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('End Ride'),
                            onPressed: () {
                              ride.endRideManually();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.electricCyan,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.near_me_rounded, size: 18),
                            label: const Text(
                              'Test Arrival',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              ride.triggerArrivalAlert(
                                  destinationName: 'Technology Tower (TT)');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.badge.copyWith(color: color)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption.copyWith(fontSize: 10)),
      ],
    );
  }
}
