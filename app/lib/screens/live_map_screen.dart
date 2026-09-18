import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shuttle_provider.dart';
import '../providers/ride_provider.dart';
import '../widgets/animated_campus_map.dart';
import '../widgets/check_in_button.dart';
import '../widgets/ride_details_sheet.dart';
import '../widgets/arrival_payment_dialog.dart';
import '../widgets/shuttle_loading_indicator.dart';
import '../theme/colors.dart';

class LiveMapScreen extends StatelessWidget {
  const LiveMapScreen({Key? key}) : super(key: key);

  void _showRideDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RideDetailsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer2<ShuttleProvider, RideProvider>(
        builder: (context, shuttleProv, ride, child) {
          if (shuttleProv.isLoading) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: ShuttleLoadingIndicator(),
            );
          }

          return Stack(
            children: [
              // 1. Live Interactive Map
              Positioned.fill(
                child: AnimatedCampusMap(
                  routes: shuttleProv.routes,
                  shuttles: shuttleProv.shuttles,
                  selectedShuttle: shuttleProv.selectedShuttle,
                  onShuttleTapped: (id) {
                    shuttleProv.selectShuttle(id);
                    _showRideDetails(context);
                  },
                ),
              ),

              // 2. Floating Morphing Check-in Button
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: CheckInButton(
                  onExpandSheet: () => _showRideDetails(context),
                ),
              ),

              // 3. Arrival Payment Dialog Overlay (if triggered)
              if (ride.showArrivalModal)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: const Center(
                    child: ArrivalPaymentDialog(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
