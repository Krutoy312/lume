import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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
  final _categoryController = TextEditingController();
  XFile? _photo;

  /// selectedDays[0] = Monday (ISO weekday 1) … [6] = Sunday (ISO 7).
  final List<bool> _selectedDays = List.filled(7, false);

  bool _saved = false; // guard against double-save

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
          category: _categoryController.text.trim().isEmpty
              ? 'Средство'
              : _categoryController.text.trim(),
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
    _categoryController.dispose();
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

              // ── Title ───────────────────────────────────────────────────────
              const Text('Добавить средство', style: _titleStyle),
              SizedBox(height: w * 0.061),

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

              // ── Photo button ────────────────────────────────────────────────
              _PhotoButton(
                hasPhoto: _photo != null,
                onTap: _pickPhoto,
              ),
              SizedBox(height: w * 0.051),

              // ── Name field ──────────────────────────────────────────────────
              _InputField(
                controller: _nameController,
                label: 'Название продукта',
                hint: 'Например, Laneige Cream',
              ),
              SizedBox(height: w * 0.031),

              // ── Category field ──────────────────────────────────────────────
              _InputField(
                controller: _categoryController,
                label: 'Категория',
                hint: 'Например, Сыворотка',
              ),
              SizedBox(height: w * 0.051),

              // ── Schedule section ────────────────────────────────────────────
              const Text('График применения', style: AppTextStyles.sectionLabel),
              SizedBox(height: w * 0.031),
              _DaySelector(
                selectedDays: _selectedDays,
                onToggle: (i) => setState(() => _selectedDays[i] = !_selectedDays[i]),
              ),
              SizedBox(height: w * 0.061),

              // ── "Fill by photo" — inactive ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.primaryLighter.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(w * 0.038),
                    ),
                    padding: EdgeInsets.symmetric(vertical: w * 0.041),
                    disabledForegroundColor: AppColors.primaryLighter,
                  ),
                  child: const Text(
                    'Заполнить по фото',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.primaryLighter,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Title style ──────────────────────────────────────────────────────────────

const TextStyle _titleStyle = TextStyle(
  fontFamily: 'SF Pro',
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: AppColors.primaryDark,
  height: 1.4,
);

// ─── Photo button ─────────────────────────────────────────────────────────────

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.hasPhoto, required this.onTap});

  final bool hasPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        hasPhoto ? Icons.edit_outlined : Icons.add_a_photo_outlined,
        size: 16,
        color: AppColors.golden,
      ),
      label: Text(
        hasPhoto ? 'Изменить фото' : 'Добавить фото',
        style: const TextStyle(
          fontFamily: 'SF Pro',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.golden,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.golden, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(w * 0.038),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.041,
          vertical: w * 0.025,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.golden,
      ),
    );
  }
}

// ─── Input field ──────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
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
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          fontFamily: 'SF Pro',
          fontSize: 13,
          color: AppColors.primaryMedium,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'SF Pro',
          fontSize: 13,
          color: AppColors.primaryLighter,
        ),
        filled: true,
        fillColor: AppColors.scaffoldBackground,
        contentPadding: EdgeInsets.symmetric(
          horizontal: w * 0.041,
          vertical: w * 0.031,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(w * 0.031),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(w * 0.031),
          borderSide: const BorderSide(color: AppColors.golden, width: 1),
        ),
      ),
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
