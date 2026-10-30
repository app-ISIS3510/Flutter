import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/parking_controller.dart';
import '../models/parking.dart';
import '../models/parking_catalog_snapshot.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';
import '../utils/screen_load_reporter.dart';

class ParkingMapPanel extends StatefulWidget {
  final ParkingController controller;
  final ValueChanged<Map<String, String>> onSelectParking;
  final VoidCallback onOpenParkingList;
  final Widget activeParkingCard;
  final AnalyticsController? analytics;

  const ParkingMapPanel({
    super.key,
    required this.controller,
    required this.onSelectParking,
    required this.onOpenParkingList,
    required this.activeParkingCard,
    this.analytics,
  });

  @override
  State<ParkingMapPanel> createState() => _ParkingMapPanelState();
}

class _ParkingMapPanelState extends State<ParkingMapPanel>
    with WidgetsBindingObserver {
  final _connectivity = ConnectivityService();
  StreamSubscription<bool>? _connectionSubscription;
  late Future<ParkingCatalogSnapshot?> _catalogFuture;
  bool? _hasNetwork;
  bool _unavailable = false;
  int _mapAttempt = 0;
  int _connectionRevision = 0;
  ScreenLoadReporter? _screenLoad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenLoad = ScreenLoadReporter(widget.analytics, 'home');
    _catalogFuture = _loadCatalog();
    _connectionSubscription = _connectivity.onNetworkChanged.listen(
      _onConnectionChanged,
      onError: (Object _) {},
    );
  }

  Future<ParkingCatalogSnapshot?> _loadCatalog() async {
    final revision = _connectionRevision;
    final checked = await _connectivity.connectionStatus();
    if (!mounted) return null;
    final connected = revision == _connectionRevision ? checked : _hasNetwork;
    if (connected == false) {
      _hasNetwork = false;
      return null;
    }
    return widget.controller.loadParkingCatalog();
  }

  void _onConnectionChanged(bool connected) {
    if (!mounted) return;
    _connectionRevision++;
    final reconnecting = _hasNetwork == false && connected;
    setState(() {
      _hasNetwork = connected;
      if (!connected) _unavailable = true;
      if (reconnecting) {
        _unavailable = false;
        _mapAttempt++;
        _catalogFuture = _loadCatalog();
      }
    });
  }

  void _retryMap() {
    setState(() {
      _screenLoad?.cancel();
      _screenLoad = ScreenLoadReporter(
        widget.analytics,
        'home',
        trigger: 'refresh',
      );
      _unavailable = false;
      _mapAttempt++;
      _catalogFuture = _loadCatalog();
    });
  }

  @override
  void didUpdateWidget(covariant ParkingMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _catalogFuture = _loadCatalog();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        _connectivity.connectionStatus().then((connected) {
          if (connected != null && mounted) _onConnectionChanged(connected);
        }),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionSubscription?.cancel();
    _screenLoad?.cancel();
    super.dispose();
  }

  Map<String, String> _selection(Parking parking) => {
    'id': parking.id,
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

  Widget _fallback(BuildContext context) {
    _screenLoad?.presented(context, source: 'none', failed: true);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Map unavailable',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              _hasNetwork == false
                  ? 'Go online to view the map, or browse parking lots.'
                  : 'Open the parking list to continue.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: widget.onOpenParkingList,
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('View parking lots'),
            ),
            if (_hasNetwork != false)
              TextButton(
                onPressed: _retryMap,
                child: const Text('Try map again'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasNetwork == false || _unavailable) return _fallback(context);
    return FutureBuilder<ParkingCatalogSnapshot?>(
      future: _catalogFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data;
        if (snapshot.hasError || catalog == null || catalog.isFromCache) {
          return _fallback(context);
        }
        _screenLoad?.presented(context, source: 'network');
        final markers = catalog.parkingLots
            .where((parking) {
              final lat = parking.latitude;
              final lng = parking.longitude;
              return lat != null &&
                  lng != null &&
                  lat.isFinite &&
                  lng.isFinite &&
                  lat >= -90 &&
                  lat <= 90 &&
                  lng >= -180 &&
                  lng <= 180;
            })
            .map(
              (parking) => Marker(
                markerId: MarkerId(parking.id),
                position: LatLng(parking.latitude!, parking.longitude!),
                infoWindow: InfoWindow(
                  title: parking.name,
                  snippet: parking.address,
                ),
                onTap: () => widget.onSelectParking(_selection(parking)),
              ),
            )
            .toSet();
        return Stack(
          children: [
            Positioned.fill(
              child: _ParkingMapCanvas(
                key: ValueKey(_mapAttempt),
                markers: markers,
                onInitializationTimeout: () {
                  if (mounted) setState(() => _unavailable = true);
                },
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 16,
              child: widget.activeParkingCard,
            ),
          ],
        );
      },
    );
  }
}

class _ParkingMapCanvas extends StatefulWidget {
  final Set<Marker> markers;
  final VoidCallback onInitializationTimeout;
  const _ParkingMapCanvas({
    super.key,
    required this.markers,
    required this.onInitializationTimeout,
  });
  @override
  State<_ParkingMapCanvas> createState() => _ParkingMapCanvasState();
}

class _ParkingMapCanvasState extends State<_ParkingMapCanvas> {
  Timer? _initializationTimeout;
  @override
  void initState() {
    super.initState();
    _initializationTimeout = Timer(const Duration(seconds: 12), () {
      if (mounted) widget.onInitializationTimeout();
    });
  }

  @override
  void dispose() {
    _initializationTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GoogleMap(
    initialCameraPosition: const CameraPosition(
      target: LatLng(4.6030, -74.0660),
      zoom: 15.5,
    ),
    markers: widget.markers,
    onMapCreated: (_) => _initializationTimeout?.cancel(),
    myLocationButtonEnabled: false,
    zoomControlsEnabled: false,
    mapToolbarEnabled: false,
  );
}
