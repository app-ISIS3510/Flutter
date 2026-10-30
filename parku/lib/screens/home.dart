import 'package:flutter/material.dart';

import '../controllers/parking_controller.dart';
import '../controllers/analytics_controller.dart';
import '../controllers/session_controller.dart';
import '../models/parking.dart';
import '../models/parking_session.dart';
import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/parking_map_panel.dart';

class HomeScreen extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback onOpenMyParking;
  final ValueChanged<Map<String, String>> onSelectParking;
  final ParkingController parkingController;
  final SessionController sessionController;
  final AnalyticsController? analytics;

  const HomeScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    required this.onOpenMyParking,
    required this.onSelectParking,
    required this.parkingController,
    required this.sessionController,
    this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(32, 22, 32, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ParkU',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => onNavTap(1),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('Parking lots'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenMyParking,
                  icon: const Icon(Icons.local_parking_rounded),
                  label: const Text('My parking'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ParkingMapPanel(
                analytics: analytics,
                controller: parkingController,
                onSelectParking: onSelectParking,
                onOpenParkingList: () => onNavTap(1),
                activeParkingCard: _ActiveParkingCard(
                  sessionController: sessionController,
                  parkingController: parkingController,
                  onOpen: onOpenMyParking,
                ),
              ),
            ),
            const SizedBox(height: 15),
            NavBar(currentIndex: currentIndex, onTap: onNavTap),
          ],
        ),
      ),
    );
  }
}

class _ActiveParkingData {
  final ParkingSession? session;
  final Parking? parking;

  const _ActiveParkingData({this.session, this.parking});
}

class _ActiveParkingCard extends StatefulWidget {
  final SessionController sessionController;
  final ParkingController parkingController;
  final VoidCallback onOpen;

  const _ActiveParkingCard({
    required this.sessionController,
    required this.parkingController,
    required this.onOpen,
  });

  @override
  State<_ActiveParkingCard> createState() => _ActiveParkingCardState();
}

class _ActiveParkingCardState extends State<_ActiveParkingCard> {
  late Future<_ActiveParkingData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _ActiveParkingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionController != widget.sessionController ||
        oldWidget.parkingController != widget.parkingController) {
      _future = _load();
    }
  }

  Future<_ActiveParkingData> _load() async {
    final session = await widget.sessionController.loadActiveSession().timeout(
      const Duration(seconds: 10),
    );
    if (session == null) return const _ActiveParkingData();
    final details = await widget.parkingController.loadParkingDetails(
      session.parkingId,
    );
    return _ActiveParkingData(session: session, parking: details.parking);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MY PARKING',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<_ActiveParkingData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const Text('Could not refresh your active parking.');
              }
              final session = snapshot.data?.session;
              final parking = snapshot.data?.parking;
              if (session == null) {
                return const Text(
                  'No active parking',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                );
              }
              final pickup = TimeOfDay.fromDateTime(
                session.pickupTime.toLocal(),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parking?.name ?? 'Active parking',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Pick up at ${MaterialLocalizations.of(context).formatTimeOfDay(pickup)}',
                  ),
                  if (parking != null) Text(parking.address),
                  if (session.isFromCache)
                    const Text(
                      'Saved confirmed session; current status may be outdated.',
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onOpen,
              child: const Text('View my parking'),
            ),
          ),
        ],
      ),
    );
  }
}
