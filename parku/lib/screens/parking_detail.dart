import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/analytics_controller.dart';

class ParkingDetailScreen extends StatefulWidget {
  final Map<String, String> parking;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback onParkHere;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final NavigationController navigationController;
  final AnalyticsController analyticsController;

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
  });

  @override
  State<ParkingDetailScreen> createState() =>
      _ParkingDetailScreenState();
}

class _ParkingDetailScreenState extends State<ParkingDetailScreen> {
  Future<void> _openWaze() async {
    final latitude = double.tryParse(
      widget.parking['latitude'] ?? '',
    );

    final longitude = double.tryParse(
      widget.parking['longitude'] ?? '',
    );

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parking location is not available.'),
        ),
      );
      return;
    }

    try {

      await widget.analyticsController.track(
        eventType: 'navigation_opened',
        screen: 'parking_detail',
        parkingId: widget.parking['id'],
        metadata: {
          'provider': 'waze',
        },
      );

          await widget.navigationController.openWaze(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Waze: $error'),
        ),
      );
    }
  }

  Future<void> _openGoogleMaps() async {
    final latitude = double.tryParse(
      widget.parking['latitude'] ?? '',
    );

    final longitude = double.tryParse(
      widget.parking['longitude'] ?? '',
    );

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parking location is not available.'),
        ),
      );
      return;
    }

    try {
      await widget.analyticsController.track(
        eventType: 'navigation_opened',
        screen: 'parking_detail',
        parkingId: widget.parking['id'],
        metadata: {
          'provider': 'google_maps',
        },
      );
      await widget.navigationController.openGoogleMaps(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Google Maps: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name =
        widget.parking['name'] ?? 'Parking lot';

    final String address =
        widget.parking['address'] ?? 'Address unavailable';
    
    final String openingTime =
    widget.parking['openingTime'] ?? '';

    final String closingTime =
        widget.parking['closingTime'] ?? '';

    final String carSpaces =
        widget.parking['carSpaces'] ?? '0';

    final String motorcycleSpaces =
        widget.parking['motorcycleSpaces'] ?? '0';

    final String pricePerMinute =
        widget.parking['pricePerMinute'] ?? '0';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  30,
                  20,
                  30,
                  24,
                ),
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
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/cityuimage.png',
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: InkWell(
                            onTap: widget.onToggleFavorite,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: AppColors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
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
                            onPressed: _openWaze,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SecondaryButton(
                            text: 'Google Maps',
                            onPressed: _openGoogleMaps,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onParkHere,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: 17,
                          ),
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
                        onPressed: widget.onToggleFavorite,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.lightPurple,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            vertical: 17,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.isFavorite
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
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 24,
          ),
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
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.lightPurple,
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(
          vertical: 17,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}