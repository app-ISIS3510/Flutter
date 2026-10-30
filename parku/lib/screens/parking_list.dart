import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/parking_controller.dart';
import '../models/most_used_parking.dart';
import '../models/parking.dart';
import '../models/smart_parking_result.dart';
import '../services/connectivity_service.dart';
import '../services/parking_service.dart';
import '../state/parking_list_state.dart';
import '../theme/app_theme.dart';
import '../utils/screen_load_reporter.dart';
import '../widgets/most_used_parking_section.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/parking_card.dart';

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
  final _connectivity = ConnectivityService();

  StreamSubscription<bool>? _subscription;
  Timer? _reconnectTimer;
  ScreenLoadReporter? _screenLoad;

  late Stream<ParkingListState> _parkingStream;
  late Future<SmartParkingResults> _resultsFuture;
  late Future<List<MostUsedParking>> _mostUsedFuture;

  bool? _hasNetwork;
  bool _catalogRefreshing = true;
  bool _smartLoading = true;
  bool _refreshPending = false;

  int _smartVersion = 0;
  int _selectedRadius = 1000;
  SmartVehicleType _selectedVehicle = SmartVehicleType.car;
  String? _openingParkingId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _parkingStream = _createParkingStream();
    _loadResults();
    _mostUsedFuture = widget.controller.loadMostUsedParkingLots();

    _subscription = _connectivity.onNetworkChanged.listen(
      _onNetworkChanged,
      onError: (Object error, StackTrace stack) {
        developer.log(
          'Could not monitor connection',
          error: error,
          stackTrace: stack,
        );
      },
    );

    unawaited(_checkConnection());
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

    _catalogRefreshing = true;

    return widget.controller.watchParkingLots().map((state) {
      _catalogRefreshing = state.isRefreshing;
      _finishRefresh();
      return state;
    });
  }

  void _finishRefresh() {
    if (!_catalogRefreshing && !_smartLoading && _refreshPending) {
      _refreshPending = false;
      _scheduleRefresh();
    }
  }

  void _onNetworkChanged(bool connected) {
    if (!mounted) return;

    final reconnected = _hasNetwork == false && connected;
    _hasNetwork = connected;

    if (!connected) {
      _reconnectTimer?.cancel();
      _refreshPending = false;
    } else if (reconnected) {
      _scheduleRefresh();
    }
  }

  Future<void> _checkConnection({bool refresh = false}) async {
    try {
      final connected = await _connectivity.hasNetworkConnection();

      if (!mounted) return;

      _onNetworkChanged(connected);

      if (connected && refresh) {
        _scheduleRefresh();
      }
    } catch (error, stack) {
      developer.log(
        'Could not check connection',
        error: error,
        stackTrace: stack,
      );
    }
  }

  void _scheduleRefresh() {
    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted || _hasNetwork != true) return;

      if (_catalogRefreshing || _smartLoading) {
        _refreshPending = true;
        return;
      }

      _refreshLocation();
    });
  }

  @override
  void didUpdateWidget(covariant ParkingListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _parkingStream = _createParkingStream();
      _loadResults();
      _mostUsedFuture = widget.controller.loadMostUsedParkingLots();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkConnection(refresh: true));
    }
  }

  @override
  void dispose() {
    _smartVersion++;
    _screenLoad?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  void _loadResults() {
    _smartLoading = true;
    final version = ++_smartVersion;

    final request = Future<SmartParkingResults>.sync(
      () => widget.controller.loadSmartParkingResults(
        radiusMeters: _selectedRadius,
        vehicleType: _selectedVehicle,
      ),
    );

    _resultsFuture = request;

    void finished() {
      if (!mounted || version != _smartVersion) return;
      _smartLoading = false;
      _finishRefresh();
    }

    unawaited(
      request.then<void>(
        (_) => finished(),
        onError: (Object _, StackTrace _) => finished(),
      ),
    );
  }

  void _changeRadius(int radius) {
    if (_selectedRadius == radius) return;

    setState(() {
      _selectedRadius = radius;
      _loadResults();
    });
  }

  void _changeVehicle(SmartVehicleType vehicle) {
    if (_selectedVehicle == vehicle) return;

    setState(() {
      _selectedVehicle = vehicle;
      _loadResults();
    });
  }

  void _refreshLocation() {
    if (!mounted || _catalogRefreshing || _smartLoading) return;

    setState(() {
      _parkingStream = _createParkingStream(trigger: 'refresh');
      _loadResults();
      _mostUsedFuture = widget.controller.loadMostUsedParkingLots();
    });
  }

  void _reloadMostUsed() {
    if (!mounted) return;

    setState(() {
      _mostUsedFuture = widget.controller.loadMostUsedParkingLots();
    });
  }

  Future<void> _openMostUsed(MostUsedParking selected) async {
    if (_openingParkingId != null || widget.onSelectParking == null) {
      return;
    }

    setState(() => _openingParkingId = selected.parkingId);

    try {
      final parking = await widget.controller
          .loadParkingById(selected.parkingId)
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (parking == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This parking lot is no longer available. Refresh the ranking.',
            ),
          ),
        );
        return;
      }

      widget.onSelectParking!(_parkingToMap(parking));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open this parking lot. Please try again later.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingParkingId = null);
      }
    }
  }

  Map<String, String> _parkingToMap(Parking parking) {
    return {
      'id': parking.id,
      'imageUrl': parking.imageUrl ?? '',
      'name': parking.name,
      'address': parking.address,
      'latitude': parking.latitude?.toString() ?? '',
      'longitude': parking.longitude?.toString() ?? '',
      'carSpaces': parking.availableCarSpaces.toString(),
      'motorcycleSpaces': parking.availableMotorcycleSpaces.toString(),
      'pricePerMinute': parking.pricePerMinute.toString(),
      'openingTime': parking.openingTime ?? '',
      'closingTime': parking.closingTime ?? '',
    };
  }

  Widget _buildRadiusButton(int radius, String label, bool loading) {
    final selected = _selectedRadius == radius;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton(
          onPressed: loading ? null : () => _changeRadius(radius),
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? AppColors.primary : Colors.white,
            foregroundColor: selected ? Colors.white : AppColors.primary,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.lightPurple,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleButton(
    SmartVehicleType vehicle,
    String label,
    IconData icon,
    bool loading,
  ) {
    final selected = _selectedVehicle == vehicle;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton.icon(
          onPressed: loading ? null : () => _changeVehicle(vehicle),
          icon: Icon(icon, size: 19),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? AppColors.primary : Colors.white,
            foregroundColor: selected ? Colors.white : AppColors.primary,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.lightPurple,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(bool loading) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildVehicleButton(
                SmartVehicleType.car,
                'Car',
                Icons.directions_car,
                loading,
              ),
              _buildVehicleButton(
                SmartVehicleType.motorcycle,
                'Motorcycle',
                Icons.two_wheeler,
                loading,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Search radius',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildRadiusButton(500, '500 m', loading),
              _buildRadiusButton(1000, '1 km', loading),
              _buildRadiusButton(2000, '2 km', loading),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : _refreshLocation,
              icon: const Icon(Icons.my_location, size: 20),
              label: const Text('Refresh location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: AppColors.lightPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParkingCard(SmartParkingResult result) {
    final parking = result.parking;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ParkingCard(
        name: parking.name,
        address: parking.address,
        type: _selectedVehicle == SmartVehicleType.car
            ? '${result.totalSpaces} car spaces'
            : '${result.totalSpaces} motorcycle spaces',
        distance: result.formattedDistance,
        availabilityPercentage: result.availabilityPercentage,
        availableSpaces: result.availableSpaces,
        totalSpaces: result.totalSpaces,
        isRecommended: result.isRecommended,
        onTap: widget.onSelectParking == null
            ? null
            : () => widget.onSelectParking!(_parkingToMap(parking)),
      ),
    );
  }

  Widget _buildCatalogCard(Parking parking) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ParkingCard(
        name: parking.name,
        address: parking.address,
        type:
            '${parking.carSpaces} car spaces · '
            '${parking.motorcycleSpaces} motorcycle spaces',
        onTap: widget.onSelectParking == null
            ? null
            : () => widget.onSelectParking!(_parkingToMap(parking)),
      ),
    );
  }

  Widget _buildHeader(bool loading, String? locationNotice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 20),
        MostUsedParkingSection(
          future: _mostUsedFuture,
          onRetry: _reloadMostUsed,
          openingParkingId: _openingParkingId,
          onSelectParking: widget.onSelectParking == null
              ? null
              : _openMostUsed,
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Find a place to park',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildFilters(loading),
        if (locationNotice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                locationNotice,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildError(Object? error) {
    final message = error is TimeoutException
        ? 'The server took too long to respond. Please try again later.'
        : 'Could not load parking lots. Please try again later.';

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _refreshLocation,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<ParkingListState>(
                stream: _parkingStream,
                builder: (context, catalogSnapshot) {
                  final catalog = catalogSnapshot.data;

                  return FutureBuilder<SmartParkingResults>(
                    future: _resultsFuture,
                    builder: (context, snapshot) {
                      final loading =
                          snapshot.connectionState == ConnectionState.waiting;

                      final data = loading ? null : snapshot.data;
                      final results = data?.items ?? [];

                      final useCatalog =
                          data == null && catalog?.hasData == true;

                      final lots = useCatalog
                          ? catalog!.parkingLots!
                          : <Parking>[];

                      final count = useCatalog
                          ? lots.length
                          : results.length;

                      final waiting =
                          !useCatalog &&
                          data == null &&
                          (loading ||
                              catalog?.isRefreshing == true ||
                              catalogSnapshot.connectionState ==
                                  ConnectionState.waiting);

                      final failed =
                          !waiting && !useCatalog && data == null;

                      final notices = [
                        if (data?.locationNotice != null)
                          data!.locationNotice!,
                        if (data != null && catalog?.isFromCache == true)
                          'Saved availability estimate.',
                        if (useCatalog)
                          loading
                              ? 'All parking lots. Nearby results are loading.'
                              : 'Nearby search unavailable. Showing all parking lots.',
                      ];

                      if (data != null || useCatalog || !waiting) {
                        _screenLoad?.presented(
                          context,
                          source: failed
                              ? 'none'
                              : catalog?.isFromCache == true
                              ? 'sqlite'
                              : 'network',
                          failed: failed,
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: 1 + (count == 0 ? 1 : count),
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildHeader(
                              loading,
                              notices.isEmpty ? null : notices.join('\n'),
                            );
                          }

                          if (waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (failed) {
                            return _buildError(snapshot.error);
                          }

                          if (count == 0) {
                            return Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                useCatalog
                                    ? 'No parking lots available.'
                                    : data?.locationNotice == null
                                    ? 'No parking lots found within the selected radius.'
                                    : 'No parking lots found for this vehicle type.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.greyText,
                                ),
                              ),
                            );
                          }

                          return useCatalog
                              ? _buildCatalogCard(lots[index - 1])
                              : _buildParkingCard(results[index - 1]);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            NavBar(
              currentIndex: widget.currentIndex,
              onTap: widget.onNavTap,
            ),
          ],
        ),
      ),
    );
  }
}