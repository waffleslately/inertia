import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/route.dart';
import '../providers/shuttle_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class AnimatedCampusMap extends StatefulWidget {
  final List<RouteModel> routes;
  final List<InterpolatedShuttle> shuttles;
  final InterpolatedShuttle? selectedShuttle;
  final Function(String shuttleId)? onShuttleTapped;

  const AnimatedCampusMap({
    Key? key,
    required this.routes,
    required this.shuttles,
    this.selectedShuttle,
    this.onShuttleTapped,
  }) : super(key: key);

  @override
  State<AnimatedCampusMap> createState() => _AnimatedCampusMapState();
}

class _AnimatedCampusMapState extends State<AnimatedCampusMap>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TransformationController _transController = TransformationController();

  // VIT Vellore Bounds
  final double latMin = 12.9640;
  final double latMax = 12.9785;
  final double lngMin = 79.1510;
  final double lngMax = 79.1675;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapWidth = constraints.maxWidth;
        final mapHeight = constraints.maxHeight;

        return Stack(
          children: [
            // Interactive Zoom & Pan Canvas
            InteractiveViewer(
              transformationController: _transController,
              minScale: 0.8,
              maxScale: 3.5,
              boundaryMargin: const EdgeInsets.all(120),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(mapWidth, mapHeight),
                    painter: CampusMapPainter(
                      routes: widget.routes,
                      shuttles: widget.shuttles,
                      selectedShuttleId: widget.selectedShuttle?.model.shuttleId,
                      pulseValue: _pulseController.value,
                      latMin: latMin,
                      latMax: latMax,
                      lngMin: lngMin,
                      lngMax: lngMax,
                    ),
                  );
                },
              ),
            ),

            // Top Status Overlay (Campus Pill & Live Indicator)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Campus Name Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.electricCyan,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.electricCyan,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'VIT VELLORE',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.electricCyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'LIVE',
                            style: AppTypography.badge.copyWith(
                              color: AppColors.electricCyan,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Active Shuttles Counter Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.directions_bus_filled_rounded,
                          color: AppColors.electricCyan,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.shuttles.length} Active',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class CampusMapPainter extends CustomPainter {
  final List<RouteModel> routes;
  final List<InterpolatedShuttle> shuttles;
  final String? selectedShuttleId;
  final double pulseValue;
  final double latMin;
  final double latMax;
  final double lngMin;
  final double lngMax;

  CampusMapPainter({
    required this.routes,
    required this.shuttles,
    this.selectedShuttleId,
    required this.pulseValue,
    required this.latMin,
    required this.latMax,
    required this.lngMin,
    required this.lngMax,
  });

  Offset _geoToPixel(double lat, double lng, Size size) {
    // Normalization: (lat - min) / (max - min)
    // Note: Lat increases upwards, so Y is inverted: (1.0 - normLat) * height
    final normX = (lng - lngMin) / (lngMax - lngMin);
    final normY = 1.0 - ((lat - latMin) / (latMax - latMin));

    // Pad within screen margins
    const pad = 40.0;
    final w = size.width - (pad * 2);
    final h = size.height - (pad * 2);

    return Offset(pad + normX * w, pad + normY * h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Subtle Tech Grid Background
    final gridPaint = Paint()
      ..color = AppColors.border.withOpacity(0.25)
      ..strokeWidth = 1.0;

    const step = 45.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Draw Routes (Glowing neon underlay + crisp core line)
    for (var route in routes) {
      if (route.polyline.length < 2) continue;

      final path = Path();
      final p0 = _geoToPixel(route.polyline[0][0], route.polyline[0][1], size);
      path.moveTo(p0.dx, p0.dy);

      for (int i = 1; i < route.polyline.length; i++) {
        final pt = _geoToPixel(route.polyline[i][0], route.polyline[i][1], size);
        path.lineTo(pt.dx, pt.dy);
      }

      final routeColor = route.id == 'route_1'
          ? AppColors.electricCyan
          : AppColors.electricBlue;

      // Glow layer
      final glowPaint = Paint()
        ..color = routeColor.withOpacity(0.25)
        ..strokeWidth = 10.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, glowPaint);

      // Core crisp line
      final linePaint = Paint()
        ..color = routeColor
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, linePaint);

      // 3. Draw Route Stops
      for (var stop in route.stops) {
        final stopPt = _geoToPixel(stop.latitude, stop.longitude, size);

        // Stop Outer Ring
        final stopOuterPaint = Paint()
          ..color = routeColor.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(stopPt, 8.0, stopOuterPaint);

        // Stop Center Dot
        final stopDotPaint = Paint()
          ..color = AppColors.textPrimary
          ..style = PaintingStyle.fill;
        canvas.drawCircle(stopPt, 4.0, stopDotPaint);

        // Stop Label
        final textSpan = TextSpan(
          text: stop.name,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(stopPt.dx - textPainter.width / 2, stopPt.dy + 10),
        );
      }
    }

    // 4. Draw Animated Shuttles with Smooth Interpolation & Pulsing Crowd Radius
    for (var shuttle in shuttles) {
      final pos = _geoToPixel(shuttle.currentLat, shuttle.currentLng, size);
      final model = shuttle.model;

      // Determine crowd color
      Color crowdColor = AppColors.electricCyan;
      if (model.crowdCategory == 'Medium') {
        crowdColor = AppColors.crowdMedium;
      } else if (model.crowdCategory == 'Crowded') {
        crowdColor = AppColors.crowdHigh;
      }

      // A. Pulsing Crowd Density Radius (Breathing effect)
      // Radius expands based on crowd ratio (e.g. 24px - 44px)
      final baseRadius = 20.0 + (model.crowdRatio * 20.0);
      final pulseRadius = baseRadius + (pulseValue * 12.0);
      final pulseOpacity = (1.0 - pulseValue).clamp(0.0, 0.7);

      final pulsePaint = Paint()
        ..color = crowdColor.withOpacity(pulseOpacity * 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, pulseRadius, pulsePaint);

      // B. Core Shuttle Halo
      final haloPaint = Paint()
        ..color = crowdColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, baseRadius, haloPaint);

      // C. Rotated Shuttle Vehicle Marker
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      // Convert bearing degrees to radians
      final rad = (shuttle.targetBearing * math.pi) / 180.0;
      canvas.rotate(rad);

      // Shuttle body (rounded rect)
      final bodyPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(const Rect.fromLTWH(-11, -16, 22, 32))
        ..style = PaintingStyle.fill;

      final bodyBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final rrect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -15, 20, 30),
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, bodyPaint);
      canvas.drawRRect(rrect, bodyBorderPaint);

      // Front windshield
      final glassPaint = Paint()
        ..color = AppColors.background
        ..style = PaintingStyle.fill;
      final glassRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, -12, 14, 7),
        const Radius.circular(2),
      );
      canvas.drawRRect(glassRRect, glassPaint);

      canvas.restore();

      // D. Floating Live ETA & Crowd Badge Chip Above Shuttle
      final etaText = model.etaDisplay;
      final stopName = model.nextStopName ?? 'En Route';
      final chipText = '$stopName • $etaText';

      final chipSpan = TextSpan(
        text: chipText,
        style: const TextStyle(
          color: AppColors.background,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      );
      final chipPainter = TextPainter(
        text: chipSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final chipWidth = chipPainter.width + 16;
      const chipHeight = 20.0;
      final chipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          pos.dx - chipWidth / 2,
          pos.dy - 38,
          chipWidth,
          chipHeight,
        ),
        const Radius.circular(10),
      );

      final chipBgPaint = Paint()
        ..color = AppColors.electricCyan
        ..style = PaintingStyle.fill;
      canvas.drawRRect(chipRect, chipBgPaint);

      chipPainter.paint(
        canvas,
        Offset(pos.dx - chipPainter.width / 2, pos.dy - 34),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CampusMapPainter oldDelegate) {
    return true; // Repaint on pulse tick or shuttle position interpolation
  }
}
