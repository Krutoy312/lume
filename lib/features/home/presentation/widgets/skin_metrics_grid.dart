import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.assetPath,
  });

  final String label;
  final int value;
  final String assetPath;
}

const _metrics = [
  _MetricData(label: 'Матовость', value: 6, assetPath: 'assets/icons/ic_haze.svg'),
  _MetricData(label: 'Насыщенность', value: 7, assetPath: 'assets/icons/ic_saturation.svg'),
  _MetricData(label: 'Увлажнённость', value: 8, assetPath: 'assets/icons/ic_moisture.svg'),
  _MetricData(label: 'Комфорт', value: 4, assetPath: 'assets/icons/ic_comfort.svg'),
];

class SkinMetricsGrid extends StatelessWidget {
  const SkinMetricsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051;
    final gap = w * 0.030;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Показатели кожи',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: w * 0.030),
          // Row 1
          Row(
            children: [
              Expanded(child: _MetricCard(data: _metrics[0])),
              SizedBox(width: gap),
              Expanded(child: _MetricCard(data: _metrics[1])),
            ],
          ),
          SizedBox(height: gap),
          // Row 2
          Row(
            children: [
              Expanded(child: _MetricCard(data: _metrics[2])),
              SizedBox(width: gap),
              Expanded(child: _MetricCard(data: _metrics[3])),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cardPad = w * 0.046;

    return Container(
      height: w * 0.351,
      padding: EdgeInsets.fromLTRB(cardPad, w * 0.036, cardPad, w * 0.036),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            data.assetPath,
            width: w * 0.046,
            height: w * 0.046,
          ),
          const Spacer(),
          Text(
            data.label,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: w * 0.028),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${data.value}',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(width: w * 0.008),
              Text(
                '/10',
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 12,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          SizedBox(height: w * 0.020),
          // Mini progress bar
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: Stack(
              children: [
                Container(
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.progressBarBack,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: data.value / 10,
                  child: Container(
                    height: 7,
                    decoration: const BoxDecoration(
                      gradient: AppColors.metricsGradient,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
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
