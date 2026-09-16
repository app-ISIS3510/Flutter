import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';

class HomeScreen extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;

  final bool hasActiveParking;
  final VoidCallback onOpenMyParking;

  const HomeScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    required this.hasActiveParking,
    required this.onOpenMyParking,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ENCABEZADO
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 22, 32, 22),
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

            // MAPA
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/map.png',
                      fit: BoxFit.cover,
                    ),
                  ),

                  // CAJA DE UBICACIÓN
                  Positioned(
                    top: 20,
                    left: 30,
                    right: 30,
                    child: Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
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
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // MARCADORES
                  const Positioned(
                    top: 160,
                    left: 210,
                    child: ParkingMarker(),
                  ),

                  const Positioned(
                    top: 270,
                    right: 100,
                    child: ParkingMarker(),
                  ),

                  const Positioned(
                    top: 310,
                    left: 120,
                    child: ParkingMarker(),
                  ),

                  // TARJETA MY PARKING
                  Positioned(
                    left: 30,
                    right: 30,
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ETIQUETA
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 170,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.lightPurple,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                'MY PARKING',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // CONTENIDO SIN PARQUEO
                          if (!hasActiveParking) ...[
                            const Text(
                              'No active parking',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your current parking will appear here.',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.greyText,
                              ),
                            ),
                          ]

                          // CONTENIDO CON PARQUEO
                          else ...[
                            const Text(
                              'City U Parking',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Car ABC123 · Pick up at 4:00 PM',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.greyText,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Calle 20 · Las Aguas, Bogotá',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.greyText,
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // BOTÓN
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
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                hasActiveParking
                                    ? 'View my parking'
                                    : 'My parking',
                                style: const TextStyle(
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
              ),
            ),

            const SizedBox(height: 15),

            // BARRA DE NAVEGACIÓN
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

class ParkingMarker extends StatelessWidget {
  const ParkingMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.location_on_outlined,
          color: AppColors.primary,
          size: 34,
        ),
      ),
    );
  }
}