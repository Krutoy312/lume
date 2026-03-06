import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/shelf_controller.dart';

/// Modal bottom sheet for adding a new product to the "toTry" list.
///
/// Saves automatically when dismissed (swipe or barrier tap) if the
/// product name is not empty.
class AddProductSheet extends ConsumerStatefulWidget {
  const AddProductSheet({super.key});

  @override
  ConsumerState<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<AddProductSheet> {
  final _nameController = TextEditingController();
  String? _selectedCategory;
  XFile? _photo;

  /// selectedDays[0] = Monday (ISO weekday 1) … [6] = Sunday (ISO 7).
  final List<bool> _selectedDays = List.filled(7, false);

  bool _saved = false; // guard against double-save

  static const _categories = [
    'Очищение',
    'Сыворотка',
    'SPF',
    'Увлажнение',
    'Тоник',
    'Маска',
    'Актив',
  ];

  // ── Save logic ──────────────────────────────────────────────────────────────

  void _save() {
    if (_saved) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    _saved = true;

    final schedule = <int>[
      for (int i = 0; i < 7; i++)
        if (_selectedDays[i]) i + 1, // ISO weekday (1=Mon … 7=Sun)
    ];

    ref.read(shelfProvider.notifier).addProductToTry(
          name: name,
          category: _selectedCategory ?? 'Средство',
          photoLocalPath: _photo?.path,
          schedule: schedule.isEmpty ? null : schedule,
        );
  }

  // ── Photo picker ────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _photo = picked);
    }
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(w * 0.061),
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: w * 0.051,
            right: w * 0.051,
            top: w * 0.031,
            bottom: w * 0.051 + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ─────────────────────────────────────────────────
              Center(
                child: Container(
                  width: w * 0.102,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLighter.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: w * 0.051),

              // ── Title row ───────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text('Добавьте средство', style: _titleStyle),
                  ),
                  SizedBox(width: w * 0.031),
                  _FillByPhotoButton(w: w),
                ],
              ),
              SizedBox(height: w * 0.051),

              // ── Photo preview ───────────────────────────────────────────────
              if (_photo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(w * 0.038),
                  child: Image.file(
                    File(_photo!.path),
                    height: w * 0.46,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: w * 0.031),
              ],

              // ── Name field ──────────────────────────────────────────────────
              Text('Название', style: _fieldLabelStyle),
              SizedBox(height: w * 0.020),
              _NameField(controller: _nameController, w: w),
              SizedBox(height: w * 0.041),

              // ── Category chips ──────────────────────────────────────────────
              Text('Категория', style: _fieldLabelStyle),
              SizedBox(height: w * 0.020),
              _CategoryChips(
                categories: _categories,
                selected: _selectedCategory,
                onSelect: (cat) => setState(
                  () => _selectedCategory = _selectedCategory == cat ? null : cat,
                ),
                w: w,
              ),
              SizedBox(height: w * 0.041),

              // ── Schedule section ────────────────────────────────────────────
              Text('График использования', style: _scheduleHeaderStyle),
              SizedBox(height: w * 0.031),
              _DaySelector(
                selectedDays: _selectedDays,
                onToggle: (i) => setState(() => _selectedDays[i] = !_selectedDays[i]),
              ),
              SizedBox(height: w * 0.041),

              // ── Add photo button ────────────────────────────────────────────
              GestureDetector(
                onTap: _pickPhoto,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: w * 0.038,
                      color: AppColors.primaryMedium,
                    ),
                    SizedBox(width: w * 0.015),
                    Text(
                      _photo != null ? 'Изменить фото продукта' : 'Добавить фото продукта',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryMedium,
                        letterSpacing: -0.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Text styles ──────────────────────────────────────────────────────────────

const TextStyle _titleStyle = TextStyle(
  fontFamily: 'SF Pro',
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: AppColors.primaryDark,
  letterSpacing: -0.5,
  height: 1.25,
);

const TextStyle _fieldLabelStyle = TextStyle(
  fontFamily: 'SF Pro',
  fontSize: 16,
  fontWeight: FontWeight.w300,
  color: AppColors.primaryDark,
  height: 1.5,
);

const TextStyle _scheduleHeaderStyle = TextStyle(
  fontFamily: 'SF Pro',
  fontSize: 16,
  fontWeight: FontWeight.w300,
  color: AppColors.primaryDark,
  letterSpacing: -0.5,
  height: 1.25,
);

// ─── "Заполнить по фото" pill — inactive golden gradient ─────────────────────

class _FillByPhotoButton extends StatelessWidget {
  const _FillByPhotoButton({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: w * 0.066, // ~26 px
        padding: EdgeInsets.symmetric(horizontal: w * 0.038),
        decoration: const BoxDecoration(
          gradient: AppColors.metricsGradient,
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: w * 0.038, color: Colors.white),
            SizedBox(width: w * 0.015),
            const Text(
              'Заполнить по фото',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                letterSpacing: -0.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Name input field ─────────────────────────────────────────────────────────

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.w});

  final TextEditingController controller;
  final double w;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontFamily: 'SF Pro',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.primaryDark,
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText: 'Введите название...',
        hintStyle: const TextStyle(
          fontFamily: 'SF Pro',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryMedium,
        ),
        filled: false,
        contentPadding: EdgeInsets.symmetric(
          horizontal: w * 0.038,
          vertical: w * 0.020,
        ),
        constraints: BoxConstraints(minHeight: w * 0.076),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: AppColors.scaffoldBackground,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: AppColors.scaffoldBackground,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.golden, width: 1),
        ),
      ),
    );
  }
}

// ─── Category chips ───────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
    required this.w,
  });

  final List<String> categories;
  final String? selected;
  final void Function(String) onSelect;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: w * 0.020,
      runSpacing: w * 0.020,
      children: categories.map((cat) {
        final isSelected = cat == selected;
        return GestureDetector(
          onTap: () => onSelect(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeInOut,
            height: w * 0.061, // ~24 px
            padding: EdgeInsets.symmetric(horizontal: w * 0.038),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.golden : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected ? AppColors.golden : AppColors.primaryDark,
                width: 0.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              cat,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isSelected ? Colors.white : AppColors.primaryDark,
                height: 1.0,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Day selector ─────────────────────────────────────────────────────────────

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.selectedDays, required this.onToggle});

  final List<bool> selectedDays;
  final void Function(int index) onToggle;

  static const _labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final size = w * 0.099; // ~39 px

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final selected = selectedDays[i];
        return GestureDetector(
          onTap: () => onToggle(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.golden : Colors.transparent,
              border: selected
                  ? null
                  : Border.all(
                      color: AppColors.primaryLighter.withValues(alpha: 0.5),
                      width: 1,
                    ),
            ),
            alignment: Alignment.center,
            child: Text(
              _labels[i],
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? AppColors.surface : AppColors.primaryDark,
              ),
            ),
          ),
        );
      }),
    );
  }
}
