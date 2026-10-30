import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../controllers/parking_controller.dart';
import '../controllers/analytics_controller.dart';
import '../utils/screen_load_reporter.dart';
import '../models/parking_option.dart';
import '../models/vehicle.dart';
import '../state/nearby_parking_state.dart';

class SearchScreen extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final ValueChanged<String> onSearch;
  final ParkingController parkingController;
  final AnalyticsController? analytics;
  final Vehicle? selectedVehicle;
  final ValueChanged<Map<String, String>>? onSelectParking;

  const SearchScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    required this.onSearch,
    required this.parkingController,
    this.selectedVehicle,
    this.onSelectParking,
    this.analytics,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late Future<NearbyParkingState> _optionsFuture;
  ScreenLoadReporter? _screenLoad;

  @override
  void initState() {
    super.initState();
    _optionsFuture = _loadOptions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Future<NearbyParkingState> _loadOptions() {
    _screenLoad?.cancel();
    _screenLoad = ScreenLoadReporter(
      widget.analytics,
      'search',
      trigger: _screenLoad == null ? 'navigation' : 'refresh',
    );
    return widget.parkingController.loadNearbyParking(
      vehicleType: widget.selectedVehicle?.type,
    );
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedVehicle?.type != widget.selectedVehicle?.type ||
        oldWidget.parkingController != widget.parkingController) {
      _optionsFuture = _loadOptions();
    }
  }

  String _locationMessage(Object? error) {
    if (error is TimeoutException) {
      return 'Could not get your location. Check your GPS and reopen search.';
    }
    return switch (error.toString()) {
      'Exception: Location services are disabled.' =>
        'Turn on your device location to find nearby parking lots.',
      'Exception: Location permission was denied.' ||
      'Exception: Location permission was permanently denied.' => 'Allow ParkU to use your location in your device settings to find nearby parking lots.',
      _ => 'Could not load nearby parking lots. Check your location settings and connection.',
    };
  }

  @override
  void dispose() {
    _screenLoad?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    widget.onSearch(query);
  }

  void _selectSuggestion(String parkingName) {
    _searchController.text = parkingName;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: parkingName.length),
    );

    FocusScope.of(context).unfocus();
    widget.onSearch(parkingName);
  }

  void _openNearbyParking(ParkingOption option) {
    final onSelect = widget.onSelectParking;
    if (onSelect == null) {
      _selectSuggestion(option.parking.name);
      return;
    }
    FocusScope.of(context).unfocus();
    final parking = option.parking;
    onSelect({
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
    });
  }

  void _retryNearbyParking() {
    setState(() => _optionsFuture = _loadOptions());
  }

  Widget _nearbyMessage(String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: AppColors.greyText)),
        TextButton(
          onPressed: _retryNearbyParking,
          child: const Text('Retry nearby parking'),
        ),
      ],
    );
  }

  String _distanceLabel(double meters) {
    final distance = meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(1)} km';
    return '$distance away (straight-line)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
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
                        const Text(
                          'Search',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Search by name',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 9),
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _performSearch(),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.white,
                        hintText: 'Enter parking lot name',
                        hintStyle: const TextStyle(color: AppColors.greyText),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0DCEA),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'NEAREST PARKING LOTS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.selectedVehicle == null
                          ? 'Select a vehicle in Profile to see its availability.'
                          : 'Availability for your ${widget.selectedVehicle!.type.label.toLowerCase()} · ${widget.selectedVehicle!.plate}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<NearbyParkingState>(
                      future: _optionsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          _screenLoad?.presented(
                            context,
                            source: 'none',
                            failed: true,
                          );
                          return _nearbyMessage(
                            _locationMessage(snapshot.error),
                          );
                        }

                        final state = snapshot.data;
                        _screenLoad?.presented(
                          context,
                          source: state == null
                              ? 'none'
                              : state.isFromCache
                              ? 'sqlite'
                              : 'network',
                          failed: state == null || state.errorMessage != null,
                        );
                        if (state == null || state.errorMessage != null) {
                          return _nearbyMessage(
                            state?.errorMessage ??
                                'Could not load nearby parking lots.',
                          );
                        }
                        final suggestedParkingLots = state.options;

                        if (suggestedParkingLots.isEmpty) {
                          return _nearbyMessage(
                            state.isFromCache
                                ? 'No saved parking lots with valid coordinates '
                                      'are available. Connect to the Internet and retry.'
                                : 'No nearby parking lots are available to display.',
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.isFromCache) ...[
                              const Text(
                                'Showing the nearest saved parking lots. '
                                'Availability and prices may be outdated.',
                                style: TextStyle(color: AppColors.greyText),
                              ),
                              if (state.updatedAt != null)
                                Text(
                                  'Oldest saved update: '
                                  '${state.updatedAt!.toLocal().toString().split('.').first}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.greyText,
                                  ),
                                ),
                            ],
                            TextButton(
                              onPressed: _retryNearbyParking,
                              child: const Text('Refresh nearby parking'),
                            ),
                            ...suggestedParkingLots.take(4).map((option) {
                              final parking = option.parking;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () {
                                    _openNearbyParking(option);
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          parking.name,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _distanceLabel(option.distanceMeters),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.greyText,
                                          ),
                                        ),
                                        if (option.availableSpaces != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            option.isFromCache
                                                ? '${option.availableSpaces} saved estimated spaces · '
                                                      '${(option.availabilityRatio! * 100).round()}% of capacity'
                                                : '${option.availableSpaces} estimated spaces · '
                                                      '${(option.availabilityRatio! * 100).round()}% of capacity',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.greyText,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
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
