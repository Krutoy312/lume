import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../shelf/data/models/daily_routine_model.dart';
import '../../../shelf/data/models/product_model.dart';
import '../../../shelf/data/models/shelf_model.dart';
import '../../../shelf/presentation/controllers/routine_controller.dart';
import '../../../shelf/presentation/controllers/shelf_controller.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

void showRoutineSheet(BuildContext context, {required bool isEvening}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RoutineSheet(isEvening: isEvening),
  );
}

// ─── Root sheet widget ────────────────────────────────────────────────────────

class RoutineSheet extends ConsumerWidget {
  const RoutineSheet({super.key, required this.isEvening});

  final bool isEvening;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.sizeOf(context).width;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.88, 0.95],
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(w * 0.061),
            ),
          ),
          child: _SheetBody(
            scrollController: scrollController,
            isEvening: isEvening,
            w: w,
          ),
        );
      },
    );
  }
}

// ─── Sheet body ───────────────────────────────────────────────────────────────

class _SheetBody extends ConsumerWidget {
  const _SheetBody({
    required this.scrollController,
    required this.isEvening,
    required this.w,
  });

  final ScrollController scrollController;
  final bool isEvening;
  final double w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routineAsync = ref.watch(routineProvider);
    final shelfData = ref.watch(shelfProvider).data;
    final productMap = _buildProductMap(shelfData);

    return routineAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (routine) {
        final slot =
            isEvening ? routine?.eveningRoutine : routine?.morningRoutine;
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(child: _Handle(w: w)),
            SliverToBoxAdapter(
              child: _HeaderBlock(isEvening: isEvening, slot: slot, w: w),
            ),
            SliverToBoxAdapter(child: SizedBox(height: w * 0.051)),
            ..._buildSections(context, ref, slot, productMap),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.paddingOf(context).bottom + w * 0.051,
              ),
            ),
          ],
        );
      },
    );
  }

  static Map<String, ProductModel> _buildProductMap(ShelfModel? shelf) {
    if (shelf == null) return {};
    final all = [...shelf.my.morning, ...shelf.my.evening];
    return {for (final p in all) p.id: p};
  }

  List<Widget> _buildSections(
    BuildContext context,
    WidgetRef ref,
    RoutineSlotModel? slot,
    Map<String, ProductModel> productMap,
  ) {
    if (slot == null) return [];
    final slivers = <Widget>[];

    // 1. Planned — "Сегодняшний уход"
    if (slot.planned.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: _SectionHeader(title: 'Сегодняшний уход', w: w),
      ));
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: w * 0.025)));
      slivers.add(SliverList.separated(
        itemCount: slot.planned.length,
        separatorBuilder: (_, __) => SizedBox(height: w * 0.025),
        itemBuilder: (_, i) {
          final id = slot.planned[i];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.051),
            child: _SwipeableProductCard(
              key: ValueKey('planned_$id'),
              productId: id,
              product: productMap[id],
              w: w,
              onComplete: () {
                HapticFeedback.mediumImpact();
                ref
                    .read(routineProvider.notifier)
                    .markUsed(id, isEvening: isEvening);
              },
              onSkip: () {
                HapticFeedback.mediumImpact();
                ref
                    .read(routineProvider.notifier)
                    .markSkipped(id, isEvening: isEvening);
              },
            ),
          );
        },
      ));
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: w * 0.051)));
    }

    // 2. Used — "Выполнено"
    if (slot.used.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: _SectionHeader(title: 'Выполнено', w: w),
      ));
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: w * 0.025)));
      slivers.add(SliverList.separated(
        itemCount: slot.used.length,
        separatorBuilder: (_, __) => SizedBox(height: w * 0.025),
        itemBuilder: (_, i) {
          final id = slot.used[i];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.051),
            child: _DoneProductCard(
              product: productMap[id],
              isSkipped: false,
              w: w,
            ),
          );
        },
      ));
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: w * 0.051)));
    }

    // 3. Skipped — "Пропущено"
    if (slot.skipped.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: _SectionHeader(title: 'Пропущено', w: w),
      ));
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: w * 0.025)));
      slivers.add(SliverList.separated(
        itemCount: slot.skipped.length,
        separatorBuilder: (_, __) => SizedBox(height: w * 0.025),
        itemBuilder: (_, i) {
          final id = slot.skipped[i];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.051),
            child: _DoneProductCard(
              product: productMap[id],
              isSkipped: true,
              w: w,
            ),
          );
        },
      ));
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: w * 0.051)));
    }

    return slivers;
  }
}

// ─── Drag handle ──────────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  const _Handle({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: w * 0.038, bottom: w * 0.025),
        child: Container(
          width: w * 0.102,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.primaryLighter.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

// ─── Header block ─────────────────────────────────────────────────────────────

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({
    required this.isEvening,
    required this.slot,
    required this.w,
  });

  final bool isEvening;
  final RoutineSlotModel? slot;
  final double w;

  @override
  Widget build(BuildContext context) {
    final total = slot?.totalCount ?? 0;
    final done = slot?.used.length ?? 0;
    final progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.051),
      child: Container(
        padding: EdgeInsets.all(w * 0.051),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + title
            Row(
              children: [
                SvgPicture.asset(
                  isEvening
                      ? 'assets/icons/ic_moon.svg'
                      : 'assets/icons/ic_sun.svg',
                  width: w * 0.069,
                  height: w * 0.069,
                ),
                SizedBox(width: w * 0.030),
                Text(
                  isEvening ? 'Вечерний уход' : 'Утренний уход',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: w * 0.041,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: w * 0.038),
            // "Шаги: 1 /4"
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Шаги:  ',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: w * 0.036,
                    fontWeight: FontWeight.w300,
                    color: AppColors.primaryMedium,
                    height: 1.4,
                  ),
                ),
                Text(
                  '$done',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: w * 0.066,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                    height: 1.0,
                  ),
                ),
                Text(
                  '/$total',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: w * 0.036,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryLighter,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            SizedBox(height: w * 0.025),
            // Progress bar
            _SheetProgressBar(value: progress, w: w),
            SizedBox(height: w * 0.020),
            // Motivational text
            Center(
              child: Text(
                'Регулярный уход улучшает состояние кожи!',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: w * 0.030,
                  fontWeight: FontWeight.w300,
                  color: AppColors.primaryDark,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetProgressBar extends StatelessWidget {
  const _SheetProgressBar({required this.value, required this.w});

  final double value;
  final double w;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(w * 0.041),
      child: Stack(
        children: [
          Container(
            height: w * 0.030,
            color: AppColors.progressBarBack,
          ),
          FractionallySizedBox(
            widthFactor: value,
            child: Container(
              height: w * 0.030,
              decoration: const BoxDecoration(
                gradient: AppColors.progressBarGradient,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.w});

  final String title;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.051),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'SF Pro Rounded',
          fontSize: w * 0.041,
          fontWeight: FontWeight.w300,
          color: AppColors.primaryLight,
          height: 1.5,
        ),
      ),
    );
  }
}

// ─── Swipeable product card (planned) ─────────────────────────────────────────

class _SwipeableProductCard extends StatelessWidget {
  const _SwipeableProductCard({
    super.key,
    required this.productId,
    required this.product,
    required this.w,
    required this.onComplete,
    required this.onSkip,
  });

  final String productId;
  final ProductModel? product;
  final double w;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismissible_$productId'),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          onComplete();
        } else {
          onSkip();
        }
      },
      background: _SwipeBackground(
        color: const Color(0xFF3EDC77),
        icon: Icons.check,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: w * 0.051),
        w: w,
      ),
      secondaryBackground: _SwipeBackground(
        color: const Color(0xFF999999),
        icon: Icons.close,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: w * 0.051),
        w: w,
      ),
      child: _ProductCard(product: product, w: w),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.alignment,
    required this.padding,
    required this.w,
  });

  final Color color;
  final IconData icon;
  final Alignment alignment;
  final EdgeInsets padding;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      alignment: alignment,
      padding: padding,
      child: Icon(icon, color: Colors.white, size: w * 0.061),
    );
  }
}

// ─── Done / skipped product card ──────────────────────────────────────────────

class _DoneProductCard extends StatelessWidget {
  const _DoneProductCard({
    required this.product,
    required this.isSkipped,
    required this.w,
  });

  final ProductModel? product;
  final bool isSkipped;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _ProductCard(product: product, w: w),
        // Gray overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF8B8B8B).withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        // Status label
        Positioned(
          right: w * 0.038,
          bottom: w * 0.025,
          child: Text(
            isSkipped ? 'Пропущено' : 'Выполнено',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: w * 0.025,
              fontWeight: FontWeight.w500,
              color: isSkipped
                  ? AppColors.primaryMedium
                  : const Color(0xFF6F8F5A),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Base product card ────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.w});

  final ProductModel? product;
  final double w;

  @override
  Widget build(BuildContext context) {
    final name = product?.name ?? '—';
    final category = product?.category ?? '';
    final photoUrl = product?.photoUrl;
    final scheduleText = _scheduleLabel(product?.schedule);

    return Container(
      height: w * 0.232, // ~91px on 393px screen
      padding: EdgeInsets.symmetric(
        horizontal: w * 0.041,
        vertical: w * 0.030,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _ProductPhoto(url: photoUrl, w: w),
          SizedBox(width: w * 0.030),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: w * 0.036,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.45,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: w * 0.015),
                Row(
                  children: [
                    if (category.isNotEmpty) _CategoryPill(label: category, w: w),
                    const Spacer(),
                    Text(
                      scheduleText,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: w * 0.025,
                        fontWeight: FontWeight.w300,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _scheduleLabel(List<int>? schedule) {
    if (schedule == null || schedule.isEmpty || schedule.length == 7) {
      return 'Ежедневно';
    }
    final n = schedule.length;
    if (n == 1) return '1 раз в неделю';
    if (n >= 2 && n <= 4) return '$n раза в неделю';
    return '$n раз в неделю';
  }
}

// ─── Product photo thumbnail ──────────────────────────────────────────────────

class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({required this.url, required this.w});

  final String? url;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w * 0.165,
      height: w * 0.170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white, width: 1),
        color: AppColors.progressBarBack,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: url != null
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _PhotoPlaceholder(w: w),
              )
            : _PhotoPlaceholder(w: w),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.progressBarBack,
      alignment: Alignment.center,
      child: Icon(
        Icons.spa_outlined,
        color: AppColors.primaryLighter,
        size: w * 0.061,
      ),
    );
  }
}

// ─── Category pill ────────────────────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.w});

  final String label;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: w * 0.051,
      padding: EdgeInsets.symmetric(horizontal: w * 0.025),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.primaryDark, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'SF Pro Rounded',
          fontSize: w * 0.025,
          fontWeight: FontWeight.w300,
          color: AppColors.primaryDark,
          height: 1.0,
        ),
      ),
    );
  }
}
