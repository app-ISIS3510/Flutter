import 'package:flutter/material.dart';

import '../controllers/parking_controller.dart';
import '../models/parking.dart';
import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/parking_card.dart';

class ParkingListScreen extends StatelessWidget {
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
                onTap: onSearchTap,
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
                      Icon(
                        Icons.search,
                        color: AppColors.greyText,
                        size: 25,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Search parking lots',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.greyText,
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
              child: FutureBuilder<List<Parking>>(
                future: controller.loadParkingLots(),
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
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Error loading parking lots:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }

                  final parkingLots = snapshot.data ?? [];

                  if (parkingLots.isEmpty) {
                    return const Center(
                      child: Text(
                        'No parking lots available.',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.greyText,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    itemCount: parkingLots.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final parking = parkingLots[index];

                      return ParkingCard(
                        name: parking.name,
                        address: parking.address,

                        // Por ahora lo construimos con los datos reales.
                        type:
                            '${parking.carSpaces} car spaces · '
                            '${parking.motorcycleSpaces} motorcycle spaces',

                        onTap: onSelectParking == null
                            ? null
                            : () {
                                onSelectParking!({
                                  'id': parking.id,
                                  'name': parking.name,
                                  'address': parking.address,
                                  'latitude': parking.latitude?.toString() ?? '', 
                                  'longitude': parking.longitude?.toString() ?? '',
                                  'carSpaces':
                                      parking.carSpaces.toString(),
                                  'motorcycleSpaces':
                                      parking.motorcycleSpaces.toString(),
                                  'pricePerMinute':
                                      parking.pricePerMinute.toString(),
                                  'openingTime':
                                      parking.openingTime ?? '',
                                  'closingTime':
                                      parking.closingTime ?? '',
                                });
                              },
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            NavBar(
              currentIndex: currentIndex,
              onTap: onNavTap,
            ),
          ],
        ),
      ),
    );
  }
}