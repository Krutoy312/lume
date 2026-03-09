import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/product_model.dart';
import '../controllers/shelf_controller.dart';
import '../widgets/add_product_sheet.dart';
import '../widgets/product_card.dart';

class ShelfScreen extends ConsumerStatefulWidget {
  const ShelfScreen({super.key});

  @override
  ConsumerState<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends ConsumerState<ShelfScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shelfProvider.notifier).load();
    });
  }

  // ── Schedule label ─────────────────────────────────────────────────────────

  String _scheduleLabel(ProductModel product) {
    final schedule = product.schedule;
    if (schedule == null || schedule.length >= 7) return 'Ежедневно';
    final n = schedule.length;
    if (n == 1) return '1 раз в неделю';
    if (n <= 4) return '$n раза в неделю';
    return '$n раз в неделю';
  }

  bool _showPulse(ProductModel product) =>
      ref.read(shelfProvider.notifier).isScheduledForToday(product);

  void _openAddProductSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddProductSheet(),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final state = ref.watch(shelfProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: state.shelf.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.golden,
              strokeWidth: 2,
            ),
          ),
          error: (e, __) => _ErrorView(
            onRetry: () => ref.read(shelfProvider.notifier).load(),
          ),
          data: (shelf) {
            if (shelf == null) return const SizedBox.shrink();
            final notifier = ref.read(shelfProvider.notifier);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: w * 0.051,
                    right: w * 0.051,
                    top: w * 0.079,  // ~31 px
                    bottom: w * 0.061,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── "Добавленные средства" section ──────────────────
                      _ShelfSection(
                        title: 'Добавленные средства',
                        products: shelf.toTry,
                        sectionId: kShelfSectionAdded,
                        notifier: notifier,
                        scheduleLabel: _scheduleLabel,
                        showPulse: (_) => false,
                      ),
                      SizedBox(height: w * 0.061), // ~24 px inter-section gap

                      // ── "Утро" section ──────────────────────────────────
                      _ShelfSection(
                        title: 'Утро',
                        products: shelf.my.morning,
                        sectionId: kShelfSectionMorning,
                        notifier: notifier,
                        scheduleLabel: _scheduleLabel,
                        showPulse: _showPulse,
                      ),
                      SizedBox(height: w * 0.061),

                      // ── "Вечер" section ─────────────────────────────────
                      _ShelfSection(
                        title: 'Вечер',
                        products: shelf.my.evening,
                        sectionId: kShelfSectionEvening,
                        notifier: notifier,
                        scheduleLabel: _scheduleLabel,
                        showPulse: _showPulse,
                      ),
                      SizedBox(height: w * 0.061),

                      // ── "Добавить средство" button ───────────────────────
                      _AddProductButton(
                        onTap: () => _openAddProductSheet(context),
                      ),
                      SizedBox(height: w * 0.041),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Section with DragTarget ──────────────────────────────────────────────────

class _ShelfSection extends StatelessWidget {
  const _ShelfSection({
    required this.title,
    required this.products,
    required this.sectionId,
    required this.notifier,
    required this.scheduleLabel,
    required this.showPulse,
  });

  final String title;
  final List<ProductModel> products;
  final String sectionId;
  final ShelfNotifier notifier;
  final String Function(ProductModel) scheduleLabel;
  final bool Function(ProductModel) showPulse;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return DragTarget<ProductModel>(
      onWillAcceptWithDetails: (details) =>
          !products.any((p) => p.id == details.data.id),
      onAcceptWithDetails: (details) =>
          notifier.moveProduct(details.data, sectionId),
      builder: (context, candidateData, __) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: isHovered
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(w * 0.038),
                  color: AppColors.golden.withValues(alpha: 0.06),
                  border: Border.all(
                    color: AppColors.golden.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                )
              : const BoxDecoration(),
          padding: isHovered ? EdgeInsets.all(w * 0.020) : EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section label
              Text(title, style: AppTextStyles.sectionLabel),
              SizedBox(height: w * 0.031), // ~12 px label-to-card gap

              // Product cards
              if (products.isEmpty)
                _EmptySlot(sectionId: sectionId)
              else
                ...products.map(
                  (product) => Padding(
                    padding: EdgeInsets.only(bottom: w * 0.041), // ~16 px gap
                    child: ProductCard(
                      product: product,
                      scheduleLabel: scheduleLabel(product),
                      showPulse: showPulse(product),
                      onCopyToBoth: sectionId == kShelfSectionAdded
                          ? () => notifier.copyToRoutines(product)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Empty slot ───────────────────────────────────────────────────────────────

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Container(
      height: w * 0.232, // same as card height
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.038),
        border: Border.all(
          color: AppColors.primaryLighter.withValues(alpha: 0.5),
          width: 1,
        ),
        color: AppColors.surface.withValues(alpha: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        'Перетащите сюда средство',
        style: TextStyle(
          fontFamily: 'SF Pro',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.primaryLighter,
          height: 1.4,
        ),
      ),
    );
  }
}

// ─── Add product button ───────────────────────────────────────────────────────

class _AddProductButton extends StatelessWidget {
  const _AddProductButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(
          Icons.add,
          size: 14,
          color: AppColors.golden,
        ),
        label: const Text(
          'Добавить средство',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.golden,
            height: 1.4,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.golden, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(w * 0.038),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: w * 0.041,
            vertical: w * 0.010,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppColors.golden,
        ),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.primaryLight, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Не удалось загрузить полку',
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Повторить',
              style: TextStyle(
                color: AppColors.golden,
                fontFamily: 'SF Pro',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
