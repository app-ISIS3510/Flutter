import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

// Los archivos son los iconos exportados del Figma del equipo.
class DesignIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;

  const DesignIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
