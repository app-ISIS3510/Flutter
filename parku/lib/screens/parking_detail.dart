import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/analytics_controller.dart';
import '../widgets/parking_photo.dart';
import '../controllers/parking_controller.dart';
import '../models/parking.dart';
import '../state/parking_detail_state.dart';
import '../models/navigation_provider.dart';
import '../models/vehicle.dart';
import '../widgets/external_navigation.dart';
import '../models/analytics_measurements.dart';
import '../utils/screen_load_reporter.dart';
import '../widgets/user_error_notice.dart';

class ParkingDetailScreen extends StatefulWidget {
  final Map<String, String> parking;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final ValueChanged<Parking> onParkHere;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final ParkingController parkingController;
  final NavigationController navigationController;
  final AnalyticsController analyticsController;
  final ParkingDetailVisit? visit;
  final bool isFavoriteBusy;
  final String? favoriteErrorMessage;

  const ParkingDetailScreen({
    super.key,
    required this.parking,
    required this.currentIndex,
    required this.onNavTap,
    required this.onParkHere,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.navigationController,
    required this.analyticsController,
    required this.parkingController,
    this.visit,
    this.isFavoriteBusy = false,
    this.favoriteErrorMessage,
  });

  @override
  State<ParkingDetailScreen> createState() => _ParkingDetailScreenState();
}

class _ParkingDetailScreenState extends State<ParkingDetailScreen> {
  late Future<ParkingDetailState> _detailsFuture;
  ParkingDetailState? _initialDetails;
  bool _isOpeningNavigation = false;
  late ParkingDetailVisit _visit;
  late ScreenLoadReporter _screenLoad;
  bool _visitScheduled = false;
  String? _visitUserId;
  bool _allowInitialMemory = true;

  @override
  void initState() {
    super.initState();
    _startVisit();
    _initialDetails = widget.parkingController.readMemoryParkingDetails(
      widget.parking['id'] ?? '',
    );
    _detailsFuture = _loadDetails();
  }

  @override
  void didUpdateWidget(covariant ParkingDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parking['id'] != widget.parking['id'] ||
        oldWidget.parkingController != widget.parkingController ||
        oldWidget.visit != widget.visit) {
      _screenLoad.cancel();
      _startVisit();
      _initialDetails = widget.parkingController.readMemoryParkingDetails(
        widget.parking['id'] ?? '',
      );
      _detailsFuture = _loadDetails();
    }
  }

  Future<ParkingDetailState> _loadDetails() {
    final id = widget.parking['id'];
    if (id == null || id.isEmpty) {
      return Future.value(
        const ParkingDetailState(errorMessage: 'Parking lot not found.'),
      );
    }
    return widget.parkingController.loadParkingDetails(id);
  }

  void _retryDetails() {
    setState(() {
      _allowInitialMemory = false;
      _screenLoad.cancel();
      _screenLoad = ScreenLoadReporter(
        widget.analyticsController,
        'parking_detail',
        parkingId: widget.parking['id'],
        trigger: 'refresh',
      );
      _detailsFuture = _loadDetails();
    });
  }

  void _startVisit() {
    _allowInitialMemory = true;
    _visit = widget.visit ?? ParkingDetailVisit(widget.parking['id'] ?? '');
    _visitUserId = widget.analyticsController.currentUserId;
    _screenLoad = ScreenLoadReporter(
      widget.analyticsController,
      'parking_detail',
      parkingId: widget.parking['id'],
    );
  }

  void _presentDetails(BuildContext context, ParkingDetailState state) {
    final source = state.isFromMemory
        ? 'memory'
        : state.isFromCache
        ? 'sqlite'
        : 'network';
    _screenLoad.presented(context, source: source);
    if (_visitScheduled || _visit.hasBeenViewed) return;
    final visit = _visit;
    final route = ModalRoute.of(context);
    _visitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visitScheduled = false;
      if (!mounted ||
          !identical(visit, _visit) ||
          route?.isCurrent == false ||
          widget.analyticsController.currentUserId != _visitUserId) {
        return;
      }
      final metadata = visit.markViewed();
      if (metadata == null) return;
      unawaited(
        widget.analyticsController
            .track(
              eventType: 'parking_detail_viewed',
              screen: 'parking_detail',
              parkingId: visit.parkingId,
              metadata: {...metadata, 'cache_source': source},
            )
            .catchError((Object _) {}),
      );
    });
  }

  @override
  void dispose() {
    _screenLoad.cancel();
    super.dispose();
  }

  Future<void> _openWaze(Parking parking) {
    return _openNavigation(NavigationProvider.waze, parking);
  }

  void _toggleFavorite() {
    if (widget.isFavoriteBusy) {
      showUserMessage(context, 'Checking favorites. Please wait.');
    } else if (widget.onToggleFavorite != null) {
      widget.onToggleFavorite!();
    } else {
      showUserMessage(
        context,
        widget.favoriteErrorMessage ??
            'Connect once to load your favorites, then try again.',
      );
    }
  }

  Future<void> _openGoogleMaps(Parking parking) {
    return _openNavigation(NavigationProvider.googleMaps, parking);
  }

  Future<void> _openNavigation(
    NavigationProvider provider,
    Parking parking,
  ) async {
    if (_isOpeningNavigation) return;
    setState(() => _isOpeningNavigation = true);
    try {
      final openedProvider = await openExternalNavigation(
        context: context,
        controller: widget.navigationController,
        provider: provider,
        parking: parking,
      );
      if (openedProvider != null) {
        // Analytics must never prevent an external app from opening offline.
        unawaited(
          widget.analyticsController
              .track(
                eventType: 'navigation_opened',
                screen: 'parking_detail',
                parkingId: parking.id,
                metadata: {'provider': openedProvider.analyticsValue},
              )
              .catchError((Object _) {}),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningNavigation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParkingDetailState>(
      key: ValueKey((widget.parking['id'], widget.parkingController)),
      future: _detailsFuture,
      initialData: _initialDetails,
      builder: (context, snapshot) {
        final isRefreshing =
            snapshot.connectionState == ConnectionState.waiting;
        final state = snapshot.data;
        if (isRefreshing && state?.parking == null) {
          return _buildStatusScaffold(
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading parking details...'),
              ],
            ),
          );
        }

        if (snapshot.hasError || state?.parking == null) {
          _screenLoad.presented(context, source: 'none', failed: true);
          return _buildStatusScaffold(
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state?.errorMessage ?? 'Could not load parking details.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _retryDetails,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final displayed = isRefreshing && !state!.isFromCache
            ? ParkingDetailState(
                parking: state.parking,
                updatedAt: state.updatedAt,
                isFromCache: true,
                isFromMemory: true,
              )
            : state!;
        if (!isRefreshing ||
            (_allowInitialMemory && identical(state, _initialDetails))) {
          _presentDetails(context, displayed);
        }
        return _buildDetails(context, displayed, isRefreshing: isRefreshing);
      },
    );
  }

  Widget _buildStatusScaffold(Widget content) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Parking details')),
      body: SafeArea(child: Center(child: content)),
      bottomNavigationBar: NavBar(
        currentIndex: widget.currentIndex,
        onTap: widget.onNavTap,
      ),
    );
  }

  Widget _buildDetails(
    BuildContext context,
    ParkingDetailState state, {
    bool isRefreshing = false,
  }) {
    final parking = state.parking!;
    final name = parking.name;
    final address = parking.address;
    final openingTime = parking.openingTime ?? '';
    final closingTime = parking.closingTime ?? '';
    final availability = state.availability!;
    final carSpaces = availability.availableFor(VehicleType.car);
    final motorcycleSpaces = availability.availableFor(VehicleType.motorcycle);
    final pricePerMinute = parking.pricePerMinute;
    final updatedAt = state.updatedAt?.toLocal();
    final localizations = MaterialLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(30, 20, 30, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Parking details',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    if (isRefreshing) const LinearProgressIndicator(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.isFromCache
                                      ? 'Saved details'
                                      : 'Details up to date',
                                  style: const TextStyle(
                                    color: AppColors.greyText,
                                    fontSize: 13,
                                  ),
                                ),
                                if (state.isFromCache && updatedAt != null)
                                  Text(
                                    'Updated ${localizations.formatShortDate(updatedAt)} '
                                    '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(updatedAt))}',
                                    style: const TextStyle(
                                      color: AppColors.greyText,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: isRefreshing ? null : _retryDetails,
                            tooltip: 'Refresh details',
                            icon: const Icon(
                              Icons.refresh,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: ParkingPhoto(imageUrl: widget.parking['imageUrl']),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: InkWell(
                            onTap: _toggleFavorite,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: AppColors.white,
                                shape: BoxShape.circle,
                              ),
                              child: widget.isFavoriteBusy
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      widget.isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$openingTime - $closingTime',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Smart parking availability',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      availability.isFromCache
                          ? 'Saved estimate · May have changed.'
                          : 'Estimated spaces · Not reserved.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SpaceCard(
                            icon: Icons.directions_car_outlined,
                            spaces: '$carSpaces spaces',
                            price: '\$$pricePerMinute min',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SpaceCard(
                            icon: Icons.two_wheeler,
                            spaces: '$motorcycleSpaces spaces',
                            price: '\$$pricePerMinute min',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Get directions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SecondaryButton(
                            text: 'Waze',
                            onPressed: _isOpeningNavigation
                                ? null
                                : () => _openWaze(parking),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SecondaryButton(
                            text: 'Google Maps',
                            onPressed: _isOpeningNavigation
                                ? null
                                : () => _openGoogleMaps(parking),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Routes may need internet.',
                      style: TextStyle(fontSize: 12, color: AppColors.greyText),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => widget.onParkHere(parking),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Park here',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _toggleFavorite,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.lightPurple,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.isFavoriteBusy
                              ? 'Checking favorites...'
                              : widget.favoriteErrorMessage != null &&
                                    widget.onToggleFavorite != null &&
                                    !widget.isFavorite
                              ? 'Try favorites again'
                              : widget.isFavorite
                              ? 'Saved to favorites'
                              : 'Save to favorites',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Start parking when you leave your vehicle here.',
                      style: TextStyle(fontSize: 13, color: AppColors.greyText),
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

class _SpaceCard extends StatelessWidget {
  final IconData icon;
  final String spaces;
  final String price;

  const _SpaceCard({
    required this.icon,
    required this.spaces,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spaces,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.lightPurple,
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
