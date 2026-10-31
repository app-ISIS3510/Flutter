import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/parking_controller.dart';
import '../controllers/analytics_controller.dart';
import '../controllers/session_controller.dart';
import '../models/parking.dart';
import '../models/parking_session.dart';
import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/parking_map_panel.dart';
import '../widgets/parking_catalog_list.dart';
import '../services/connectivity_service.dart';

class HomeScreen extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback onOpenMyParking;
  final ValueChanged<Map<String, String>> onSelectParking;
  final ParkingController parkingController;
  final SessionController sessionController;
  final AnalyticsController? analytics;
  final ConnectivityService? connectivityService;

  const HomeScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    required this.onOpenMyParking,
    required this.onSelectParking,
    required this.parkingController,
    required this.sessionController,
    this.analytics,
    this.connectivityService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final ConnectivityService _connectivity;
  StreamSubscription<bool>? _subscription;
  bool? _connected;
  bool _showList = false;
  int _connectionRevision = 0;

  @override
  void initState() {
    super.initState();
    _connectivity = widget.connectivityService ?? ConnectivityService();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _connectivity.onNetworkChanged.listen((connected) {
      _connectionRevision++;
      if (mounted) setState(() => _connected = connected);
    }, onError: (Object _) {});
    unawaited(_checkConnection());
  }

  Future<void> _checkConnection() async {
    final revision = _connectionRevision;
    final connected = await _connectivity.connectionStatus();
    if (mounted && connected != null && revision == _connectionRevision) {
      setState(() => _connected = connected);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkConnection());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  Widget _parkingList() => ParkingCatalogList(
    controller: widget.parkingController,
    analytics: widget.analytics,
    isOffline: _connected == false,
    onSelectParking: widget.onSelectParking,
  );

  Widget _activeCard({bool offline = false}) => _ActiveParkingCard(
    sessionController: widget.sessionController,
    parkingController: widget.parkingController,
    onOpen: widget.onOpenMyParking,
    isOffline: offline,
  );

  Widget _listWithParkingCard(bool offline) => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        Expanded(child: _parkingList()),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: constraints.maxHeight * 0.6,
            ),
            child: SingleChildScrollView(child: _activeCard(offline: offline)),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final offline = _connected == false;
    final showingList = offline || _showList;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(32, 22, 32, 12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  const Text(
                    'ParkU',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  if (!offline)
                    TextButton.icon(
                      key: const ValueKey('home_catalog_toggle'),
                      onPressed: () => setState(() => _showList = !showingList),
                      icon: Icon(
                        showingList && !offline
                            ? Icons.map_outlined
                            : Icons.list_alt_rounded,
                      ),
                      label: Text(
                        showingList && !offline ? 'Map' : 'Parking lots',
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              key: const ValueKey('home_parking_content'),
              child: showingList
                  ? _listWithParkingCard(offline)
                  : ParkingMapPanel(
                      analytics: widget.analytics,
                      controller: widget.parkingController,
                      connectivityService: _connectivity,
                      onSelectParking: widget.onSelectParking,
                      onOpenParkingList: () => setState(() => _showList = true),
                      fallbackBuilder: (_) => _listWithParkingCard(offline),
                      activeParkingCard: _activeCard(),
                    ),
            ),
            const SizedBox(height: 15),
            NavBar(currentIndex: widget.currentIndex, onTap: widget.onNavTap),
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
  final bool isOffline;

  const _ActiveParkingCard({
    required this.sessionController,
    required this.parkingController,
    required this.onOpen,
    this.isOffline = false,
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
        oldWidget.parkingController != widget.parkingController ||
        oldWidget.isOffline != widget.isOffline) {
      _future = _load();
    }
  }

  Future<_ActiveParkingData> _load() async {
    if (widget.isOffline) {
      final session = await widget.sessionController.loadSavedActiveSession();
      if (session == null) return const _ActiveParkingData();
      final catalog = await widget.parkingController.loadCachedParkingCatalog();
      final matches = catalog?.parkingLots.where(
        (parking) => parking.id == session.parkingId,
      );
      return _ActiveParkingData(
        session: session,
        parking: matches == null || matches.isEmpty ? null : matches.first,
      );
    }
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
                return const Text('Open My parking to check your session.');
              }
              final session = snapshot.data?.session;
              final parking = snapshot.data?.parking;
              if (session == null) {
                return Text(
                  widget.isOffline
                      ? 'No active parking saved'
                      : 'No active parking',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
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
                  if (session.isFromCache || widget.isOffline)
                    const Text('Last confirmed session'),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('View my parking'),
            ),
          ),
        ],
      ),
    );
  }
}
