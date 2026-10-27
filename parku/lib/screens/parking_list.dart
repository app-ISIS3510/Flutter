
import 'package:flutter/material.dart';

import '../controllers/parking_controller.dart';
import '../models/parking.dart';
import '../models/smart_parking_result.dart';
import '../services/parking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/parking_card.dart';

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
  State<ParkingListScreen> createState() =>
      _ParkingListScreenState();
}

class _ParkingListScreenState extends State<ParkingListScreen> {
  int _selectedRadius = 1000;
  SmartVehicleType _selectedVehicle = SmartVehicleType.car;

  late Future<List<SmartParkingResult>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _loadResults();
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

  Map<String, String> _parkingToMap(Parking parking) {
    return {
      'id': parking.id,
      'imageUrl': parking.imageUrl ?? '',
      'name': parking.name,
      'address': parking.address,
      'latitude': parking.latitude?.toString() ?? '',
      'longitude': parking.longitude?.toString() ?? '',
      'carSpaces': parking.availableCarSpaces.toString(),
      'motorcycleSpaces':
          parking.availableMotorcycleSpaces.toString(),
      'pricePerMinute': parking.pricePerMinute.toString(),
      'openingTime': parking.openingTime ?? '',
      'closingTime': parking.closingTime ?? '',
    };
  }

  Widget _buildRadiusButton(int radius, String label) {
    final selected = _selectedRadius == radius;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton(
          onPressed: () => _changeRadius(radius),
          style: OutlinedButton.styleFrom(
            backgroundColor:
                selected ? AppColors.primary : Colors.white,
            foregroundColor:
                selected ? Colors.white : AppColors.primary,
            side: BorderSide(
              color: selected
                  ? AppColors.primary
                  : AppColors.lightPurple,
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
  ) {
    final selected = _selectedVehicle == vehicle;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton.icon(
          onPressed: () => _changeVehicle(vehicle),
          icon: Icon(icon, size: 19),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            backgroundColor:
                selected ? AppColors.primary : Colors.white,
            foregroundColor:
                selected ? Colors.white : AppColors.primary,
            side: BorderSide(
              color: selected
                  ? AppColors.primary
                  : AppColors.lightPurple,
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

  Widget _buildFilters() {
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
              ),
              _buildVehicleButton(
                SmartVehicleType.motorcycle,
                'Motorcycle',
                Icons.two_wheeler,
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
              _buildRadiusButton(500, '500 m'),
              _buildRadiusButton(1000, '1 km'),
              _buildRadiusButton(2000, '2 km'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _refreshLocation,
              icon: const Icon(
                Icons.my_location,
                size: 20,
              ),
              label: const Text('Refresh location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                ),
                side: const BorderSide(
                  color: AppColors.lightPurple,
                ),
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

  Widget _buildParkingResults(
    List<SmartParkingResult> results,
  ) {
    if (results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No parking lots found within the selected radius.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.greyText,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        32,
        12,
        32,
        20,
      ),
      itemCount: results.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final result = results[index];
        final parking = result.parking;

        return ParkingCard(
          name: parking.name,
          address: parking.address,
          type: _selectedVehicle == SmartVehicleType.car
              ? '${parking.carSpaces} car spaces'
              : '${parking.motorcycleSpaces} motorcycle spaces',
          distance: result.formattedDistance,
          availabilityPercentage:
              result.availabilityPercentage,
          availableSpaces: result.availableSpaces,
          totalSpaces: result.totalSpaces,
          isRecommended: result.isRecommended,
          onTap: widget.onSelectParking == null
              ? null
              : () {
                  widget.onSelectParking!(
                    _parkingToMap(parking),
                  );
                },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                32,
                22,
                32,
                18,
              ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
              ),
              child: InkWell(
                onTap: widget.onSearchTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: AppColors.greyText,
                        size: 25,
                      ),
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
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 32,
              ),
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
            _buildFilters(),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<SmartParkingResult>>(
                future: _resultsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_off_outlined,
                              size: 40,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Unable to load nearby parking lots.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.greyText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _refreshLocation,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return _buildParkingResults(
                    snapshot.data ?? [],
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
