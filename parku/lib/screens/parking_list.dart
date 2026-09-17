import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/parking_card.dart';

class ParkingListScreen extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final ValueChanged<Map<String, String>>? onSelectParking;

  const ParkingListScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    this.onSelectParking,
  });

  @override
  Widget build(BuildContext context) {
    final parkingLots = [
      {
        'name': 'City U Parking',
        'address': 'Calle 20 · Las Aguas, Bogotá',
        'type': 'Cars and motorcycles · Indoor',
      },
      {
        'name': 'MetroPark Center',
        'address': '45 Market St',
        'type': 'Indoor',
      },
      {
        'name': 'University Lot C',
        'address': '102 Campus Drive',
        'type': 'Outdoor',
      },
      {
        'name': 'Library Underground',
        'address': '250 Civic Center',
        'type': 'Indoor',
      },
    ];

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
                onTap: () {
                  // Luego conectamos esto con SearchScreen
                },
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

            // LIST
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                itemCount: parkingLots.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final parking = parkingLots[index];

                  return ParkingCard(
                    name: parking['name']!,
                    address: parking['address']!,
                    type: parking['type']!,
                    onTap: onSelectParking == null ? null : () => onSelectParking!(parking),
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

