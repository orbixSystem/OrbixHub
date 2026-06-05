import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'brand_mark.dart';

/// Branded splash shown while the session bootstraps (silent-login attempt).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.graphite,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 34, onDark: true),
            SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.brandBright,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
