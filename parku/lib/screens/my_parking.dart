import 'dart:async';

import 'package:flutter/material.dart';

import '../models/parking.dart';
import '../models/parking_session.dart';
import '../theme/app_theme.dart';
import '../utils/screen_time_observer.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/user_error_notice.dart';
import 'end_parking.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/analytics_controller.dart';
import '../models/navigation_provider.dart';
import '../widgets/external_navigation.dart';

class MyParkingScreen extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final Future<void> Function()? onEndParking;
  final VoidCallback? onChangePickupTime;
  final VoidCallback? onCancelRequest;
  final NavigationController navigationController;
  final AnalyticsController? analyticsController;
  final DateTime Function() currentTime;

  final ParkingSession? session;
  final DateTime? requestedPickupTime;
  final String? requestedVehicleType;
  final String? requestedVehiclePlate;
  final Parking parking;
  final String? notice;
  final VoidCallback? onRefresh;

  const MyParkingScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    required this.session,
    required this.parking,
    required this.navigationController,
    this.onChangePickupTime,
    this.onEndParking,
    this.onCancelRequest,
    this.requestedPickupTime,
    this.requestedVehicleType,
    this.requestedVehiclePlate,
    this.notice,
    this.onRefresh,
    this.analyticsController,
    this.currentTime = DateTime.now,
  }) : assert(session != null || requestedPickupTime != null);

  @override
  State<MyParkingScreen> createState() => _MyParkingScreenState();
}

class _MyParkingScreenState extends State<MyParkingScreen> {
  bool _isOpeningNavigation = false;

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
        activeSessionId: widget.session?.id,
      );
    } finally {
      if (mounted) setState(() => _isOpeningNavigation = false);
    }
  }

  String _formatPickupTime(DateTime pickupTime) {
    final date = pickupTime.toLocal();

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
  Widget build(BuildContext context) {
    final session = widget.session;
    final pickupTime = session?.pickupTime ?? widget.requestedPickupTime!;
    final vehicleType = session?.vehicleType ?? widget.requestedVehicleType;
    final status =
        widget.notice ??
        (session?.isFromCache == true ? 'Last confirmed session' : null);
    final endParking = widget.onEndParking;
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
                      UserErrorNotice(status),
                    ],

                    const SizedBox(height: 24),

                    Center(
                      child: Text(
                        session == null
                            ? 'TIME UNTIL REQUESTED PICKUP'
                            : 'TIME UNTIL PICKUP',
                        style: const TextStyle(
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

                                _PickupCountdown(
                                  pickupTime: pickupTime,
                                  currentTime: widget.currentTime,
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
                            TextSpan(
                              text: session == null
                                  ? 'Requested pickup at '
                                  : 'Pick up at ',
                              style: const TextStyle(
                                fontSize: 17,
                                color: AppColors.greyText,
                              ),
                            ),
                            TextSpan(
                              text: _formatPickupTime(pickupTime),
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
                    if (session != null && widget.requestedPickupTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: Text(
                            'Pending pickup time: ${_formatPickupTime(widget.requestedPickupTime!)}',
                            style: const TextStyle(color: AppColors.greyText),
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
                                switch (vehicleType) {
                                  'motorcycle' => 'Motorcycle',
                                  'car' => 'Car',
                                  _ => 'Vehicle',
                                },
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.greyText,
                                ),
                              ),
                              Text(
                                session?.vehiclePlate ??
                                    widget.requestedVehiclePlate ??
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
                        onPressed: endParking == null
                            ? widget.onCancelRequest
                            : () {
                                Navigator.push(
                                  context,
                                  ScreenTimeRoute<void>(
                                    screen: 'end_parking',
                                    builder: (context) => EndParkingScreen(
                                      currentIndex: widget.currentIndex,
                                      onNavTap: widget.onNavTap,
                                      onConfirmEndParking: endParking,
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
                        child: Text(
                          session == null
                              ? 'Cancel parking request'
                              : 'I picked up my vehicle',
                          style: const TextStyle(
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

class _PickupCountdown extends StatefulWidget {
  final DateTime pickupTime;
  final DateTime Function() currentTime;

  const _PickupCountdown({required this.pickupTime, required this.currentTime});

  @override
  State<_PickupCountdown> createState() => _PickupCountdownState();
}

class _PickupCountdownState extends State<_PickupCountdown> {
  Timer? _timer;
  late int _remainingMinutes;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _remainingMinutes = _readCountdownAndScheduleUpdate();
    _lifecycleListener = AppLifecycleListener(
      onResume: _refreshCountdown,
      onHide: () => _timer?.cancel(),
    );
  }

  @override
  void didUpdateWidget(covariant _PickupCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pickupTime != oldWidget.pickupTime ||
        widget.currentTime != oldWidget.currentTime) {
      _remainingMinutes = _readCountdownAndScheduleUpdate();
    }
  }

  int _readCountdownAndScheduleUpdate() {
    _timer?.cancel();
    final remaining = widget.pickupTime.difference(widget.currentTime());
    final minutes = remaining.inMinutes;
    if (minutes <= 0) return 0;

    // The displayed value drops after crossing the whole-minute boundary.
    final untilNextMinute = remaining - Duration(minutes: minutes);
    _timer = Timer(
      untilNextMinute + const Duration(milliseconds: 1),
      _refreshCountdown,
    );
    return minutes;
  }

  void _refreshCountdown() {
    final minutes = _readCountdownAndScheduleUpdate();
    if (minutes != _remainingMinutes) {
      setState(() => _remainingMinutes = minutes);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = (_remainingMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (_remainingMinutes % 60).toString().padLeft(2, '0');
    return Text(
      '$hours:$minutes',
      style: const TextStyle(
        fontSize: 50,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
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
