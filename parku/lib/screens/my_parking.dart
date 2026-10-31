import 'dart:async';

import 'package:flutter/material.dart';

import '../models/parking.dart';
import '../models/parking_session.dart';
import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import 'end_parking.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/analytics_controller.dart';
import '../models/navigation_provider.dart';
import '../widgets/external_navigation.dart';

class MyParkingScreen extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final Future<void> Function() onEndParking;
  final VoidCallback? onChangePickupTime;
  final NavigationController navigationController;
  final AnalyticsController? analyticsController;

  final ParkingSession session;
  final Parking parking;
  final String? notice;
  final VoidCallback? onRefresh;

  const MyParkingScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    required this.onEndParking,
    required this.session,
    required this.parking,
    required this.navigationController,
    this.onChangePickupTime,
    this.notice,
    this.onRefresh,
    this.analyticsController,
  });

  @override
  State<MyParkingScreen> createState() => _MyParkingScreenState();
}

class _MyParkingScreenState extends State<MyParkingScreen> {
  Timer? _timer;
  bool _isOpeningNavigation = false;

  Duration remaining = Duration.zero;

  @override
  void initState() {
    super.initState();

    _updateRemainingTime();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _updateRemainingTime();
        });
      }
    });
  }

  Future<void> _openWaze() {
    return _openNavigation(NavigationProvider.waze);
  }

  Future<void> _openGoogleMaps() {
    return _openNavigation(NavigationProvider.googleMaps);
  }

  Future<void> _openNavigation(NavigationProvider provider) async {
    if (_isOpeningNavigation) return;
    setState(() => _isOpeningNavigation = true);
    try {
      await openExternalNavigation(
        context: context,
        controller: widget.navigationController,
        provider: provider,
        parking: widget.parking,
        analytics: widget.analyticsController,
        screen: 'my_parking',
        activeSessionId: widget.session.id,
      );
    } finally {
      if (mounted) setState(() => _isOpeningNavigation = false);
    }
  }

  void _updateRemainingTime() {
    final now = DateTime.now();

    final pickupTime = widget.session.pickupTime.toLocal();

    final difference = pickupTime.difference(now);

    if (difference.isNegative) {
      remaining = Duration.zero;
    } else {
      remaining = difference;
    }
  }

  String get remainingText {
    final hours = remaining.inHours;

    final minutes = remaining.inMinutes.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }

  String get pickupTimeText {
    final date = widget.session.pickupTime.toLocal();

    int hour = date.hour;

    final String suffix = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute $suffix';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status =
        widget.notice ??
        (widget.session.isFromCache ? 'Last confirmed session' : null);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(30, 22, 30, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'My parking',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                        if (widget.onRefresh != null)
                          IconButton(
                            onPressed: widget.onRefresh,
                            tooltip: 'Refresh parking status',
                            icon: const Icon(Icons.refresh),
                          ),
                      ],
                    ),

                    if (status != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 17,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.greyText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    const Center(
                      child: Text(
                        'TIME UNTIL PICKUP',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 16,
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.background,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: AppColors.primary,
                                  size: 38,
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  remainingText,
                                  style: const TextStyle(
                                    fontSize: 50,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                const Text(
                                  'hours : minutes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.greyText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Center(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Pick up at ',
                              style: TextStyle(
                                fontSize: 17,
                                color: AppColors.greyText,
                              ),
                            ),
                            TextSpan(
                              text: pickupTimeText,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.parking.name,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                widget.session.vehicleType == 'motorcycle'
                                    ? 'Motorcycle'
                                    : 'Car',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.greyText,
                                ),
                              ),
                              Text(
                                widget.session.vehiclePlate ??
                                    'Plate not recorded',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkText,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Text(
                            widget.parking.address,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.greyText,
                            ),
                          ),

                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: _SecondaryButton(
                                  text: 'Google Maps',
                                  onPressed: _isOpeningNavigation
                                      ? null
                                      : _openGoogleMaps,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: _SecondaryButton(
                                  text: 'Waze',
                                  onPressed: _isOpeningNavigation
                                      ? null
                                      : _openWaze,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Navigation apps may need Internet for maps and routes.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.greyText,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: widget.onChangePickupTime,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.lightPurple,
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Change pickup time',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => EndParkingScreen(
                                currentIndex: widget.currentIndex,
                                onNavTap: widget.onNavTap,
                                onConfirmEndParking: widget.onEndParking,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'I picked up my vehicle',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            NavBar(currentIndex: widget.currentIndex, onTap: widget.onNavTap),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _SecondaryButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.lightPurple,
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
