import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ParkingCard extends StatelessWidget {
  final String name;
  final String address;
  final String type;

  const ParkingCard({
    super.key,
    required this.name,
    required this.address,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Después podemos navegar a ParkingDetails
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ICON BOX
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.lightPurple,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_parking,
                color: AppColors.primary,
                size: 30,
              ),
            ),

            const SizedBox(width: 16),

            // TEXT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    address,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.greyText,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    type,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: AppColors.greyText,
            ),
          ],
        ),
      ),
    );
  }
}