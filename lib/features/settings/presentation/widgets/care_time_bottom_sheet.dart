import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ── Picker item lists ─────────────────────────────────────────────────────────

/// 00 … 23
final _hours = List.generate(24, (i) => i.toString().padLeft(2, '0'));

/// 00, 05, 10 … 55  (index × 5 gives the real minutes value)
final _mins = List.generate(12, (i) => (i * 5).toString().padLeft(2, '0'));

// ── Launcher ─────────────────────────────────────────────────────────────────

/// Shows the care-time picker sheet.
///
/// [morningMinutes] / [eveningMinutes] are total minutes from midnight.
/// Defaults: 08:00 (480) and 21:00 (1 260) when null.
Future<void> showCareTimeBottomSheet(
  BuildContext context, {
  int? morningMinutes,
  int? eveningMinutes,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,   // renders above FloatingNavBar
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: const Color(0x80000000), // 50 % black dim
    builder: (_) => ColoredBox(
      color: Colors.transparent,
      child: CareTimeBottomSheet(
        morningMinutes: morningMinutes ?? 480,   // default 08:00
        eveningMinutes: eveningMinutes ?? 1260,  // default 21:00
      ),
    ),
  );
}

// ── Main widget ───────────────────────────────────────────────────────────────

class CareTimeBottomSheet extends ConsumerStatefulWidget {
  const CareTimeBottomSheet({
    super.key,
    required this.morningMinutes,
    required this.eveningMinutes,
  });

  final int morningMinutes;
  final int eveningMinutes;

  @override
  ConsumerState<CareTimeBottomSheet> createState() =>
      _CareTimeBottomSheetState();
}

class _CareTimeBottomSheetState extends ConsumerState<CareTimeBottomSheet> {
  late final FixedExtentScrollController _morningHourCtrl;
  late final FixedExtentScrollController _morningMinCtrl;
  late final FixedExtentScrollController _eveningHourCtrl;
  late final FixedExtentScrollController _eveningMinCtrl;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Convert total minutes → (hour index, minute-step index) for each picker.
    _morningHourCtrl = FixedExtentScrollController(
      initialItem: widget.morningMinutes ~/ 60,
    );
    _morningMinCtrl = FixedExtentScrollController(
      // Clamp to nearest 5-min step index (0-11).
      initialItem: (widget.morningMinutes % 60) ~/ 5,
    );
    _eveningHourCtrl = FixedExtentScrollController(
      initialItem: widget.eveningMinutes ~/ 60,
    );
    _eveningMinCtrl = FixedExtentScrollController(
      initialItem: (widget.eveningMinutes % 60) ~/ 5,
    );
  }

  @override
  void dispose() {
    _morningHourCtrl.dispose();
    _morningMinCtrl.dispose();
    _eveningHourCtrl.dispose();
    _eveningMinCtrl.dispose();
    super.dispose();
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_loading) return;
    setState(() => _loading = true);

    final morningTotal =
        _morningHourCtrl.selectedItem * 60 + _morningMinCtrl.selectedItem * 5;
    final eveningTotal =
        _eveningHourCtrl.selectedItem * 60 + _eveningMinCtrl.selectedItem * 5;

    await ref.read(authControllerProvider.notifier).updateCareTimes(
          morningMinutes: morningTotal,
          eveningMinutes: eveningTotal,
        );

    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState is AsyncError) {
      // Reset so the user can retry.
      setState(() => _loading = false);
    } else {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final sysPad = MediaQuery.paddingOf(context).bottom;
    final bottomPad = (sysPad > 0 ? sysPad : 0.0) + 24.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        w * 0.051, // 20 px — left / right  (ref: 20 / 393)
        w * 0.061, // 24 px — top           (ref: 24 / 393)
        w * 0.051,
        bottomPad,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(w: w),
          SizedBox(height: w * 0.081), // ~32 px — ref: (471-419-20)/393
          _TimeSection(
            w: w,
            label: 'Утро',
            hourCtrl: _morningHourCtrl,
            minCtrl: _morningMinCtrl,
          ),
          SizedBox(height: w * 0.061), // ~24 px between sections
          _TimeSection(
            w: w,
            label: 'Вечер',
            hourCtrl: _eveningHourCtrl,
            minCtrl: _eveningMinCtrl,
          ),
          SizedBox(height: w * 0.061), // ~24 px before save button
          _SaveButton(w: w, loading: _loading, onTap: _save),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Выберите время',
            style: AppTextStyles.rowTitle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
              letterSpacing: -0.5,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: SvgPicture.asset(
            'assets/icons/ic_close.svg',
            width: w * 0.041,  // ~16 px
            height: w * 0.041,
            colorFilter: const ColorFilter.mode(
              AppColors.primaryMedium,
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }
}

/// One time-section (Утро or Вечер): label + two drum-pickers (Ч / М).
class _TimeSection extends StatelessWidget {
  const _TimeSection({
    required this.w,
    required this.label,
    required this.hourCtrl,
    required this.minCtrl,
  });

  final double w;
  final String label;
  final FixedExtentScrollController hourCtrl;
  final FixedExtentScrollController minCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.rowTitle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.primaryMedium, // #a89580
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: w * 0.061), // ~24 px — label → column headers
        Row(
          children: [
            // ── Hours column ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Ч',
                    style: AppTextStyles.rowTitle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: w * 0.020), // ~8 px
                  _DrumPicker(
                    controller: hourCtrl,
                    items: _hours,
                    w: w,
                  ),
                ],
              ),
            ),
            // ── Minutes column ───────────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  Text(
                    'М',
                    style: AppTextStyles.rowTitle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: w * 0.020), // ~8 px
                  _DrumPicker(
                    controller: minCtrl,
                    items: _mins,
                    w: w,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Drum picker ───────────────────────────────────────────────────────────────

/// A vertical drum/wheel that shows 3 items at a time.
///
/// The centred item is styled as selected (28 px, w500, golden 100 %);
/// the items above and below are styled as adjacent (22 px, w300, golden 60 %).
class _DrumPicker extends StatefulWidget {
  const _DrumPicker({
    required this.controller,
    required this.items,
    required this.w,
  });

  final FixedExtentScrollController controller;
  final List<String> items;
  final double w;

  @override
  State<_DrumPicker> createState() => _DrumPickerState();
}

class _DrumPickerState extends State<_DrumPicker> {
  late int _selectedIdx;

  @override
  void initState() {
    super.initState();
    _selectedIdx = widget.controller.initialItem;
    widget.controller.addListener(_onScroll);
  }

  /// Called on every scroll notification.
  /// setState is guarded so it only fires when the centred index changes.
  void _onScroll() {
    if (!mounted || !widget.controller.hasClients) return;
    final idx = widget.controller.selectedItem;
    if (idx != _selectedIdx) setState(() => _selectedIdx = idx);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // itemExtent matches the 34 px delta between items in the Figma
    // (positions 547 → 581 → 615, ref width 393 px).
    final itemExtent = widget.w * 0.0865; // ~34 px

    return SizedBox(
      height: itemExtent * 3, // show exactly 3 rows
      child: ListWheelScrollView.useDelegate(
        controller: widget.controller,
        itemExtent: itemExtent,
        physics: const FixedExtentScrollPhysics(),
        // Large diameterRatio → nearly flat list (no 3-D curvature), matching
        // the Figma which shows a completely flat vertical list.
        diameterRatio: 100.0,
        // Opacity is handled per-item below; disable the built-in fade.
        overAndUnderCenterOpacity: 1.0,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: widget.items.length,
          builder: (_, idx) {
            final isSelected = idx == _selectedIdx;
            return Center(
              child: Text(
                widget.items[idx],
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: isSelected ? 28.0 : 22.0,
                  fontWeight:
                      isSelected ? FontWeight.w500 : FontWeight.w300,
                  // golden @ 100 % selected, 60 % otherwise
                  color: AppColors.golden.withValues(
                    alpha: isSelected ? 1.0 : 0.6,
                  ),
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Save button ───────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.w,
    required this.loading,
    required this.onTap,
  });

  final double w;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: w * 0.071, // ~28 px  (ref: 28 / 393)
        decoration: BoxDecoration(
          gradient: AppColors.progressBarGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Сохранить',
                style: AppTextStyles.rowTitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.71,
                ),
              ),
      ),
    );
  }
}
