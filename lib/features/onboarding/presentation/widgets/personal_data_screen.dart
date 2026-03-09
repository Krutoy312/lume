import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/onboarding_provider.dart';

// ── Picker data ───────────────────────────────────────────────────────────────

final _days = List.generate(31, (i) => (i + 1).toString());

const _months = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

const _startYear = 1940;
const _endYear = 2026;
final _years =
    List.generate(_endYear - _startYear + 1, (i) => (_startYear + i).toString());

// ── Screen ────────────────────────────────────────────────────────────────────

/// Step 7 of the onboarding quiz — birth date (drum pickers) and gender.
class PersonalDataScreen extends ConsumerStatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  ConsumerState<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends ConsumerState<PersonalDataScreen> {
  static const int _defaultYear = 1995;
  static const int _defaultDay = 1; // day index 0 = day 1
  static const int _defaultMonth = 0; // January

  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _yearCtrl;

  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    final stored = ref.read(onboardingProvider).birthDate;
    final day = stored != null ? stored.day - 1 : _defaultDay - 1;
    final month = stored != null ? stored.month - 1 : _defaultMonth;
    final year = stored != null
        ? (stored.year - _startYear).clamp(0, _years.length - 1)
        : _defaultYear - _startYear;

    _dayCtrl = FixedExtentScrollController(initialItem: day);
    _monthCtrl = FixedExtentScrollController(initialItem: month);
    _yearCtrl = FixedExtentScrollController(initialItem: year);

    _selectedGender = ref.read(onboardingProvider).gender;
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedGender == null) return;

    final day = _dayCtrl.selectedItem + 1;
    final month = _monthCtrl.selectedItem + 1;
    final year = _startYear + _yearCtrl.selectedItem;
    final birthDate = DateTime(year, month, day);

    final notifier = ref.read(onboardingProvider.notifier);
    notifier.setBirthDate(birthDate);
    notifier.setGender(_selectedGender!);
    await notifier.submit();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051; // ~20 px
    final submitting = ref.watch(
          onboardingProvider.select((s) => s.submissionState),
        ) is AsyncLoading;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top area ────────────────────────────────────────────────────
            SizedBox(height: w * 0.122),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: _ProgressBar(w: w),
            ),
            SizedBox(height: w * 0.036),
            Padding(
              padding: EdgeInsets.only(left: hPad),
              child: Text(
                'Шаг 7 из 7',
                style: AppTextStyles.rowTitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: AppColors.primaryMedium,
                  letterSpacing: 0,
                ),
              ),
            ),
            SizedBox(height: w * 0.061),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Text(
                'Персональные данные',
                style: AppTextStyles.rowTitle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // ── Birth date ──────────────────────────────────────────────────
            SizedBox(height: w * 0.087),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Text(
                'Год рождения',
                style: AppTextStyles.rowTitle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.primaryMedium,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            SizedBox(height: w * 0.056),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                children: [
                  Expanded(
                    child: _DateDrumPicker(
                      controller: _dayCtrl,
                      items: _days,
                      w: w,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _DateDrumPicker(
                      controller: _monthCtrl,
                      items: _months,
                      w: w,
                    ),
                  ),
                  Expanded(
                    child: _DateDrumPicker(
                      controller: _yearCtrl,
                      items: _years,
                      w: w,
                    ),
                  ),
                ],
              ),
            ),

            // ── Gender ──────────────────────────────────────────────────────
            SizedBox(height: w * 0.081),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Text(
                'Пол',
                style: AppTextStyles.rowTitle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.primaryMedium,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            SizedBox(height: w * 0.061),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                children: [
                  _GenderButton(
                    label: 'Мужской',
                    value: 'male',
                    selected: _selectedGender == 'male',
                    onTap: () => setState(() => _selectedGender = 'male'),
                    w: w,
                  ),
                  SizedBox(height: w * 0.031), // ~12 px
                  _GenderButton(
                    label: 'Женский',
                    value: 'female',
                    selected: _selectedGender == 'female',
                    onTap: () => setState(() => _selectedGender = 'female'),
                    w: w,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Save button ─────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                hPad,
                w * 0.061,
                hPad,
                w * 0.061,
              ),
              child: _SaveButton(
                loading: submitting,
                enabled: _selectedGender != null,
                onTap: _submit,
                w: w,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress bar (full — step 7 of 7) ────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.w});
  final double w;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: w * 0.0305,
          decoration: BoxDecoration(
            color: AppColors.progressBarBack,
            borderRadius: BorderRadius.circular(w * 0.040),
          ),
        ),
        FractionallySizedBox(
          widthFactor: 7 / 7,
          child: Container(
            height: w * 0.0305,
            decoration: BoxDecoration(
              gradient: AppColors.progressBarGradient,
              borderRadius: BorderRadius.circular(w * 0.040),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Drum picker ───────────────────────────────────────────────────────────────

class _DateDrumPicker extends StatefulWidget {
  const _DateDrumPicker({
    required this.controller,
    required this.items,
    required this.w,
  });

  final FixedExtentScrollController controller;
  final List<String> items;
  final double w;

  @override
  State<_DateDrumPicker> createState() => _DateDrumPickerState();
}

class _DateDrumPickerState extends State<_DateDrumPicker> {
  late int _selectedIdx;

  @override
  void initState() {
    super.initState();
    _selectedIdx = widget.controller.initialItem;
    widget.controller.addListener(_onScroll);
  }

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
    final itemExtent = widget.w * 0.0865; // ~34 px — same as care time picker

    return SizedBox(
      height: itemExtent * 3,
      child: Stack(
        children: [
          ListWheelScrollView.useDelegate(
            controller: widget.controller,
            itemExtent: itemExtent,
            physics: const FixedExtentScrollPhysics(),
            diameterRatio: 100.0,
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
          // Top fade overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: itemExtent,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.scaffoldBackground,
                      Color(0x00F7F7F7),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom fade overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: itemExtent,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.scaffoldBackground,
                      Color(0x00F7F7F7),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gender button ─────────────────────────────────────────────────────────────

class _GenderButton extends StatelessWidget {
  const _GenderButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    required this.w,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  final double w;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: w * 0.112, // ~44 px
        alignment: Alignment.center,
        decoration: selected
            ? BoxDecoration(
                gradient: AppColors.progressBarGradient,
                borderRadius: BorderRadius.circular(w * 0.038),
              )
            : BoxDecoration(
                color: AppColors.scaffoldBackground,
                border: Border.all(color: const Color(0xFFD9D9D9)),
                borderRadius: BorderRadius.circular(w * 0.038),
              ),
        child: Text(
          label,
          style: AppTextStyles.rowTitle.copyWith(
            fontSize: selected ? 16.0 : 14.0,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.primaryDark,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

// ── Save button ───────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.loading,
    required this.enabled,
    required this.onTap,
    required this.w,
  });

  final bool loading;
  final bool enabled;
  final VoidCallback onTap;
  final double w;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (!loading && enabled) ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          height: w * 0.122, // ~48 px
          decoration: BoxDecoration(
            gradient: AppColors.progressBarGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Готово',
                  style: AppTextStyles.rowTitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
