import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../controllers/parking_controller.dart';
import '../models/parking.dart';
import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../controllers/session_controller.dart';
import '../models/parking_session.dart';

class HomeScreen extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback onOpenMyParking;

  final ValueChanged<Map<String, String>> onSelectParking;

  final ParkingController parkingController;
  final SessionController sessionController;


  const HomeScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    required this.onOpenMyParking,
    required this.onSelectParking,
    required this.parkingController,
    required this.sessionController,
  });

  Map<String, String> _parkingToMap(Parking parking) {
    return {
      'id': parking.id,
      'name': parking.name,
      'address': parking.address,
      'latitude': parking.latitude?.toString() ?? '',
      'longitude': parking.longitude?.toString() ?? '',
      'carSpaces': parking.carSpaces.toString(),
      'motorcycleSpaces': parking.motorcycleSpaces.toString(),
      'pricePerMinute': parking.pricePerMinute.toString(),
      'openingTime': parking.openingTime ?? '',
      'closingTime': parking.closingTime ?? '',
    };
  }

  Set<Marker> _buildMarkers(List<Parking> parkingLots) {
    return parkingLots
        .where(
          (parking) =>
              parking.latitude != null &&
              parking.longitude != null,
        )
        .map(
          (parking) => Marker(
            markerId: MarkerId(parking.id),

            position: LatLng(
              parking.latitude!,
              parking.longitude!,
            ),

            infoWindow: InfoWindow(
              title: parking.name,
              snippet: parking.address,
            ),

            onTap: () {
              onSelectParking(
                _parkingToMap(parking),
              );
            },
          ),
        )
        .toSet();
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
              padding: EdgeInsets.fromLTRB(
                32,
                22,
                32,
                22,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ParkU',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ),

            // MAP
            Expanded(
              child: FutureBuilder<List<Parking>>(
                future: parkingController.loadParkingLots(),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                        ),
                        child: Text(
                          'Error loading map:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final parkingLots =
                      snapshot.data ?? [];

                  final markers =
                      _buildMarkers(parkingLots);

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: GoogleMap(
                          initialCameraPosition:
                              const CameraPosition(
                            target: LatLng(
                              4.6030,
                              -74.0660,
                            ),
                            zoom: 15.5,
                          ),
                          markers: markers,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                        ),
                      ),

                      // LOCATION BOX
                      Positioned(
                        top: 20,
                        left: 30,
                        right: 30,
                        child: Container(
                          height: 72,
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: AppColors.primary,
                                size: 32,
                              ),
                              SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Near Universidad de los Andes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.w600,
                                    color:
                                        AppColors.darkText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // MY PARKING CARD
                      Positioned(
                        left: 30,
                        right: 30,
                        bottom: 20,
                        child: Container(
                          padding:
                              const EdgeInsets.fromLTRB(
                            20,
                            18,
                            20,
                            18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(28),
                          ),
                          child: Column(
                            mainAxisSize:
                                MainAxisSize.min,
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment:
                                    Alignment.centerLeft,
                                child: Container(
                                  width: 170,
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        AppColors.lightPurple,
                                    borderRadius:
                                        BorderRadius.circular(
                                      14,
                                    ),
                                  ),
                                  child: const Text(
                                    'MY PARKING',
                                    style: TextStyle(
                                      color:
                                          AppColors.primary,
                                      fontSize: 14,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              FutureBuilder<ParkingSession?>(
                                future: sessionController.loadActiveSession(),
                                builder: (context, sessionSnapshot) {
                                  if (sessionSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox(
                                      height: 55,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  final session = sessionSnapshot.data;

                                  if (session == null) {
                                    return const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'No active parking',
                                          style: TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.darkText,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Your current parking will appear here.',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: AppColors.greyText,
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return FutureBuilder<Parking?>(
                                    future: parkingController.loadParkingById(
                                      session.parkingId,
                                    ),
                                    builder: (context, parkingSnapshot) {
                                      if (parkingSnapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const SizedBox(
                                          height: 55,
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      }

                                      final parking = parkingSnapshot.data;

                                      if (parking == null) {
                                        return const Text(
                                          'Active parking',
                                          style: TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.darkText,
                                          ),
                                        );
                                      }

                                      final pickupTime =
                                          session.pickupTime.toLocal();

                                      int hour = pickupTime.hour;
                                      final period = hour >= 12 ? 'PM' : 'AM';

                                      hour = hour % 12;

                                      if (hour == 0) {
                                        hour = 12;
                                      }

                                      final minute = pickupTime.minute
                                          .toString()
                                          .padLeft(2, '0');

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            parking.name,
                                            style: const TextStyle(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.darkText,
                                            ),
                                          ),

                                          const SizedBox(height: 8),

                                          Text(
                                            'Car ABC123 · Pick up at '
                                            '$hour:$minute $period',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: AppColors.greyText,
                                            ),
                                          ),

                                          const SizedBox(height: 5),

                                          Text(
                                            parking.address,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.greyText,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                                                          
                              const SizedBox(height: 16),

                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: onOpenMyParking,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'View my parking',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 15),

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