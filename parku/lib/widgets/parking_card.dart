
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ParkingCard extends StatelessWidget {
  final String name;
  final String address;
  final String type;
  final VoidCallback? onTap;
  final String? distance;
  final double? availabilityPercentage;
  final int? availableSpaces;
  final int? totalSpaces;
  final bool isRecommended;

  const ParkingCard({
    super.key,
    required this.name,
    required this.address,
    required this.type,
    this.onTap,
    this.distance,
    this.availabilityPercentage,
    this.availableSpaces,
    this.totalSpaces,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isRecommended
              ? Border.all(
                  color: AppColors.primary,
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isRecommended) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightPurple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            color: AppColors.primary,
                            size: 15,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
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
                  if (distance != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$distance away',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (availabilityPercentage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${availabilityPercentage!.toStringAsFixed(1)}% available',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (availabilityPercentage! / 100)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                        minHeight: 7,
                        backgroundColor: AppColors.lightPurple,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    if (availableSpaces != null &&
                        totalSpaces != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$availableSpaces of $totalSpaces spaces available',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
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
