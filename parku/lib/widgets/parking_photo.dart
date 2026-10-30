import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../services/parking_image_cache.dart';

class ParkingPhoto extends StatelessWidget {
  static const defaultUrl =
      'https://raw.githubusercontent.com/app-ISIS3510/Flutter/main/'
      'parku/assets/images/cityuimage.png';
  final String? imageUrl;
  final BaseCacheManager? cacheManager;

  const ParkingPhoto({super.key, this.imageUrl, this.cacheManager});

  Widget _fallback() => Image.asset(
    'assets/images/cityuimage.png',
    width: double.infinity,
    height: 150,
    fit: BoxFit.cover,
  );

  @override
  Widget build(BuildContext context) {
    final url = Uri.tryParse(imageUrl?.trim() ?? '');
    final validUrl =
        url != null &&
        url.host.isNotEmpty &&
        (url.scheme == 'https' || url.scheme == 'http');
    return CachedNetworkImage(
      imageUrl: validUrl ? url.toString() : defaultUrl,
      cacheManager: cacheManager ?? ParkingImageCache.instance,
      width: double.infinity,
      height: 150,
      fit: BoxFit.cover,
      memCacheWidth: 900,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) => _fallback(),
      errorWidget: (context, url, error) => _fallback(),
    );
  }
}
