import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/parking_controller.dart';
import '../models/parking.dart';
import '../models/most_used_parking.dart';
import '../models/smart_parking_result.dart';
import '../services/parking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/parking_card.dart';
import '../widgets/most_used_parking_section.dart';

class ParkingListScreen extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final ValueChanged<Map<String, String>>? onSelectParking;
  final VoidCallback? onSearchTap;
  final ParkingController controller;

  const ParkingListScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    required this.controller,
    this.onSelectParking,
    this.onSearchTap,
  });

  @override
  State<ParkingListScreen> createState() => _ParkingListScreenState();
}

class _ParkingListScreenState extends State<ParkingListScreen> {
  int _selectedRadius = 1000;
  SmartVehicleType _selectedVehicle = SmartVehicleType.car;

  late Future<SmartParkingResults> _resultsFuture;
  late Future<List<MostUsedParking>> _mostUsedFuture;
  String? _openingParkingId;

  @override
  void initState() {
    super.initState();
    _loadResults();
    _mostUsedFuture = widget.controller.loadMostUsedParkingLots();
  }

  void _loadResults() {
    _resultsFuture = widget.controller.loadSmartParkingResults(
      radiusMeters: _selectedRadius,
      vehicleType: _selectedVehicle,
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
    setState(() {
      _loadResults();
    });
  }

  void _reloadMostUsed() {
    setState(() {
      _mostUsedFuture = widget.controller.loadMostUsedParkingLots();
    });
  }

  Future<void> _openMostUsed(MostUsedParking selected) async {
    if (_openingParkingId != null || widget.onSelectParking == null) return;
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
            'Could not open this parking lot. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingParkingId = null);
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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                      style: TextStyle(fontSize: 16, color: AppColors.greyText),
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
                style: const TextStyle(color: AppColors.darkText, fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildError(Object? error) {
    final message = error is TimeoutException
        ? 'The server took too long to respond. Please try again.'
        : 'Check your internet connection and try again.';
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
          const Text(
            'Unable to load parking lots.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.greyText),
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
              child: FutureBuilder<SmartParkingResults>(
                future: _resultsFuture,
                builder: (context, snapshot) {
                  final loading =
                      snapshot.connectionState == ConnectionState.waiting;
                  final data = loading ? null : snapshot.data;
                  final results = data?.items ?? [];
                  final showMessage =
                      loading || snapshot.hasError || results.isEmpty;
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: 1 + (showMessage ? 1 : results.length),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildHeader(loading, data?.locationNotice);
                      }
                      if (loading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (snapshot.hasError) return _buildError(snapshot.error);
                      if (results.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            data?.locationNotice == null
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
                      return _buildParkingCard(results[index - 1]);
                    },
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
