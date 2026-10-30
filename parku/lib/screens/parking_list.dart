import 'package:flutter/material.dart';

import '../controllers/parking_controller.dart';
import '../controllers/analytics_controller.dart';
import '../utils/screen_load_reporter.dart';
import '../models/parking.dart';
import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/parking_card.dart';
import '../state/parking_list_state.dart';

import 'dart:async';
import 'dart:developer' as developer;

import '../services/connectivity_service.dart';

class ParkingListScreen extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final ValueChanged<Map<String, String>>? onSelectParking;
  final VoidCallback? onSearchTap;
  final ParkingController controller;
  final AnalyticsController? analytics;

  const ParkingListScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    required this.controller,
    this.onSelectParking,
    this.onSearchTap,
    this.analytics,
  });

  @override
  State<ParkingListScreen> createState() => _ParkingListScreenState();
}

class _ParkingListScreenState extends State<ParkingListScreen>
    with WidgetsBindingObserver {
  late Stream<ParkingListState> _parkingStream;

  final _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _reconnectTimer;

  bool? _hasNetwork;
  bool _isRefreshing = true;
  bool _refreshPending = false;
  ScreenLoadReporter? _screenLoad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _parkingStream = _createParkingStream();

    _connectivitySubscription = _connectivityService.onNetworkChanged.listen(
      _onNetworkChanged,
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Could not observe network changes',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    unawaited(_readInitialConnection());
  }

  Future<void> _readInitialConnection() async {
    try {
      final hasNetwork = await _connectivityService.hasNetworkConnection();

      if (!mounted || _hasNetwork != null) return;

      _hasNetwork = hasNetwork;
    } catch (error, stackTrace) {
      developer.log(
        'Could not read network status',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Stream<ParkingListState> _createParkingStream({
    String trigger = 'navigation',
  }) {
    _screenLoad?.cancel();
    _screenLoad = ScreenLoadReporter(
      widget.analytics,
      'parking_list',
      trigger: trigger,
    );
    _isRefreshing = true;
    _refreshPending = false;

    return widget.controller.watchParkingLots().map((state) {
      _isRefreshing = state.isRefreshing;

      if (!state.isRefreshing && _refreshPending) {
        _refreshPending = false;

        if (state.errorMessage != null) {
          _scheduleReconnectRefresh();
        }
      }

      return state;
    });
  }

  void _onNetworkChanged(bool hasNetwork) {
    if (!mounted) return;

    final wasDisconnected = _hasNetwork == false;
    _hasNetwork = hasNetwork;

    if (!hasNetwork) {
      _reconnectTimer?.cancel();
      _refreshPending = false;
      return;
    }

    if (wasDisconnected) {
      _scheduleReconnectRefresh();
    }
  }

  void _scheduleReconnectRefresh() {
    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted || _hasNetwork != true) return;

      if (_isRefreshing) {
        _refreshPending = true;
        return;
      }

      _reloadParkingLots();
    });
  }

  @override
  void didUpdateWidget(covariant ParkingListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _parkingStream = _createParkingStream();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkConnectionOnResume());
    }
  }

  Future<void> _checkConnectionOnResume() async {
    try {
      final hasNetwork = await _connectivityService.hasNetworkConnection();

      if (!mounted) return;

      _hasNetwork = hasNetwork;

      if (hasNetwork) {
        _scheduleReconnectRefresh();
      } else {
        _reconnectTimer?.cancel();
        _refreshPending = false;
      }
    } catch (error, stackTrace) {
      developer.log(
        'Could not check network after resuming',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    _screenLoad?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Widget _buildParkingCards(List<Parking> parkingLots) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      itemCount: parkingLots.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final parking = parkingLots[index];

        return ParkingCard(
          name: parking.name,
          address: parking.address,

          // Por ahora lo construimos con los datos reales.
          type:
              '${parking.carSpaces} car spaces · '
              '${parking.motorcycleSpaces} motorcycle spaces',

          onTap: widget.onSelectParking == null
              ? null
              : () {
                  widget.onSelectParking!({
                    'id': parking.id,
                    'name': parking.name,
                    'address': parking.address,
                    'latitude': parking.latitude?.toString() ?? '',
                    'longitude': parking.longitude?.toString() ?? '',
                    'carSpaces': parking.availableCarSpaces.toString(),
                    'motorcycleSpaces': parking.availableMotorcycleSpaces
                        .toString(),
                    'pricePerMinute': parking.pricePerMinute.toString(),
                    'openingTime': parking.openingTime ?? '',
                    'closingTime': parking.closingTime ?? '',
                  });
                },
        );
      },
    );
  }

  void _reloadParkingLots() {
    if (!mounted || _isRefreshing) return;

    setState(() {
      _parkingStream = _createParkingStream(trigger: 'refresh');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 22, 32, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Parking lots',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ),

            // SEARCH BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: InkWell(
                onTap: widget.onSearchTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: AppColors.greyText, size: 25),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Search parking lots',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.greyText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SUBTITLE
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Find a place to park',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // LIST FROM SUPABASE
            Expanded(
              child: StreamBuilder<ParkingListState>(
                key: ObjectKey(_parkingStream),
                stream: _parkingStream,
                initialData: const ParkingListState(isRefreshing: true),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    _screenLoad?.presented(
                      context,
                      source: 'none',
                      failed: true,
                    );
                    return Center(
                      child: TextButton(
                        onPressed: _reloadParkingLots,
                        child: const Text('Could not load parking lots. Retry'),
                      ),
                    );
                  }

                  final state =
                      snapshot.data ??
                      const ParkingListState(isRefreshing: true);

                  if (!state.hasData && state.isRefreshing) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final parkingLots = state.parkingLots ?? [];
                  _screenLoad?.presented(
                    context,
                    source: state.hasData
                        ? (state.isFromCache ? 'sqlite' : 'network')
                        : 'none',
                    failed: !state.hasData,
                  );

                  return Column(
                    children: [
                      if (state.isRefreshing) const LinearProgressIndicator(),

                      if (!state.hasData && state.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                          child: Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                          ),
                        ),

                      TextButton(
                        onPressed: state.isRefreshing
                            ? null
                            : _reloadParkingLots,
                        child: const Text('Refresh'),
                      ),

                      Expanded(
                        child: !state.hasData
                            ? const Center(
                                child: Text('No saved parking lots available.'),
                              )
                            : parkingLots.isEmpty
                            ? const Center(
                                child: Text('No parking lots available.'),
                              )
                            : _buildParkingCards(parkingLots),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            NavBar(currentIndex: widget.currentIndex, onTap: widget.onNavTap),
          ],
        ),
      ),
    );
  }
}
