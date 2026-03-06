import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/product_model.dart';
import '../controllers/shelf_controller.dart';
import 'add_product_sheet.dart';
import 'pulse_indicator.dart';

/// A draggable product card for the Shelf screen.
///
/// - Tap → opens [AddProductSheet] in edit mode.
/// - Swipe left → deletes the product immediately (calls [ShelfNotifier.deleteProduct]).
/// - Long-press → activates drag-and-drop between shelf sections.
class ProductCard extends ConsumerWidget {
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
  final bool showPulse;

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddProductSheet(initialProduct: product),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.sizeOf(context).width;
    final cardWidth = w - w * 0.102; // 353/393 — card width within screen margins

    final content = _CardContent(
      product: product,
      scheduleLabel: scheduleLabel,
      showPulse: showPulse,
    );

    return GestureDetector(
      onTap: () => _openEditSheet(context),
      child: Dismissible(
        key: Key(product.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) =>
            ref.read(shelfProvider.notifier).deleteProduct(product.id),
        background: _DeleteBackground(w: w),
        child: LongPressDraggable<ProductModel>(
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
        ),
      ),
    );
  }
}

// ─── Delete background (shown on swipe-left) ──────────────────────────────────

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(right: w * 0.051),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(w * 0.038),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
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
    return const ColoredBox(color: AppColors.progressBarBack);
  }
}
