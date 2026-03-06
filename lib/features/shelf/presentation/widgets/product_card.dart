import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/product_model.dart';
import 'pulse_indicator.dart';

/// A draggable product card for the Shelf screen.
///
/// Shows product photo, name, category chip, schedule label, and an optional
/// pulsing indicator when the product is scheduled for today.
///
/// Uses [LongPressDraggable] so normal scroll gestures are not interrupted.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.scheduleLabel,
    this.showPulse = false,
  });

  final ProductModel product;

  /// Pre-computed label, e.g. "Ежедневно" or "3 раза в неделю".
  final String scheduleLabel;

  /// Whether to show the animated pulse indicator (top-right corner).
  /// Should be true only for morning/evening products scheduled for today.
  final bool showPulse;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cardWidth = w - w * 0.102; // 353/393 — card width within screen margins

    final content = _CardContent(
      product: product,
      scheduleLabel: scheduleLabel,
      showPulse: showPulse,
    );

    return LongPressDraggable<ProductModel>(
      data: product,
      delay: const Duration(milliseconds: 350),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: cardWidth,
          child: Opacity(
            opacity: 0.88,
            child: _CardContent(
              product: product,
              scheduleLabel: scheduleLabel,
              showPulse: false,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: content,
      ),
      child: content,
    );
  }
}

// ─── Card content ─────────────────────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.product,
    required this.scheduleLabel,
    required this.showPulse,
  });

  final ProductModel product;
  final String scheduleLabel;
  final bool showPulse;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cardHeight = w * 0.232;   // ~91 px
    final photoW = w * 0.165;       // ~65 px
    final photoH = w * 0.170;       // ~67 px
    final padH = w * 0.031;         // ~12 px horizontal inner padding
    final gap = w * 0.033;          // ~13 px photo→text gap
    final radius = w * 0.038;       // ~15 px

    return SizedBox(
      height: cardHeight,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // ── Main row ────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padH),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Product photo
                  Container(
                    width: photoW,
                    height: photoH,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: AppColors.surface,
                        width: 1,
                      ),
                      color: AppColors.progressBarBack,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius - 1),
                      child: product.photoUrl != null
                          ? Image.network(
                              product.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _PhotoPlaceholder(),
                            )
                          : const _PhotoPlaceholder(),
                    ),
                  ),
                  SizedBox(width: gap),
                  // Text area
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: w * 0.020,
                        top: w * 0.015,
                        bottom: w * 0.015,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            product.name,
                            style: AppTextStyles.rowTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: w * 0.008),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _CategoryChip(category: product.category),
                              const Spacer(),
                              Text(
                                scheduleLabel,
                                style: const TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.primaryDark,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Pulse indicator — top-right of card ──────────────────────────
            if (showPulse)
              const Positioned(
                top: 8,
                right: 8,
                child: PulseIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Category chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Container(
      height: w * 0.051, // ~20 px
      padding: EdgeInsets.symmetric(horizontal: w * 0.028),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryDark, width: 0.5),
        borderRadius: BorderRadius.circular(w * 0.038),
      ),
      alignment: Alignment.center,
      child: Text(
        category,
        style: const TextStyle(
          fontFamily: 'SF Pro',
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: AppColors.primaryDark,
          height: 1.2,
        ),
      ),
    );
  }
}

// ─── Photo placeholder ────────────────────────────────────────────────────────

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.progressBarBack,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.primaryLighter,
          size: 24,
        ),
      ),
    );
  }
}
