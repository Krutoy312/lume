import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ShelfScreen extends StatelessWidget {
  const ShelfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Center(
          child: Text('Shelf'),
        ),
      ),
    );
  }
}
