import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/product_model.dart';
import '../controllers/shelf_controller.dart';

// TODO(security): Replace with a server-side proxy or --dart-define injection.
// Never commit a real production token to source control.
const _kOcrApiKey = 'sk-jv6cLsjBm2OddTRcetEi2Q';
const _kGemmmaApiKey = 'sk-9vEjfsCPLOKZ_Cqfkel6vA';

/// Modal bottom sheet for adding a new product or editing an existing one.
///
/// Pass [initialProduct] to open in edit mode — all fields are pre-filled and
/// "Save on Close" calls [ShelfNotifier.updateProduct] instead of
/// [ShelfNotifier.addProductToTry].
///
/// Saves automatically when dismissed if the product name is not empty.
/// The × button discards changes without saving.
class AddProductSheet extends ConsumerStatefulWidget {
  const AddProductSheet({super.key, this.initialProduct});

  final ProductModel? initialProduct;

  @override
  ConsumerState<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<AddProductSheet> {
  final _nameController = TextEditingController();
  final _scrollController = ScrollController();
  String? _selectedCategory;
  XFile? _photo;

  /// selectedDays[0] = Monday (ISO weekday 1) … [6] = Sunday (ISO 7).
  final List<bool> _selectedDays = List.filled(7, false);

  bool _saved = false; // guard against double-save
  bool _discarded = false; // set by the × button to skip auto-save
  bool _ocrLoading = false;

  // ── Swipe-down-to-dismiss tracking ─────────────────────────────────────────
  double _dragStartY = 0;
  bool _canDismiss = false;

  static const _categories = [
    'Очищение',
    'Сыворотка',
    'SPF',
    'Увлажнение',
    'Тоник',
    'Маска',
    'Актив',
  ];

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    if (p != null) {
      _nameController.text = p.name;
      _selectedCategory = _categories.contains(p.category) ? p.category : null;
      final schedule = p.schedule;
      if (schedule != null) {
        for (int i = 0; i < 7; i++) {
          _selectedDays[i] = schedule.contains(i + 1);
        }
      }
    }
  }

  // ── Save / discard logic ────────────────────────────────────────────────────

  void _discard() {
    _discarded = true;
    Navigator.of(context).pop();
  }

  void _save() {
    if (_saved || _discarded || _ocrLoading) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    _saved = true;

    final schedule = <int>[
      for (int i = 0; i < 7; i++)
        if (_selectedDays[i]) i + 1, // ISO weekday (1=Mon … 7=Sun)
    ];

    final initial = widget.initialProduct;
    if (initial != null) {
      // Edit mode — update existing product.
      final updated = initial.copyWith(
        name: name,
        category: _selectedCategory ?? initial.category,
        schedule: schedule.isEmpty ? null : schedule,
      );
      ref
          .read(shelfProvider.notifier)
          .updateProduct(product: updated, newPhotoLocalPath: _photo?.path);
    } else {
      // Add mode — create a new product.
      ref
          .read(shelfProvider.notifier)
          .addProductToTry(
            name: name,
            category: _selectedCategory ?? 'Средство',
            photoLocalPath: _photo?.path,
            schedule: schedule.isEmpty ? null : schedule,
          );
    }
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

  // ── Fill by photo (OCR) ──────────────────────────────────────────────────

  Future<void> _fillByPhoto() async {
    // Show source selection sheet.
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Камера'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерея'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _photo = picked;
      _ocrLoading = true;
    });

    Reference? tempRef;

    try {
      // Upload to Firebase Storage and get a public download URL.
      final bytes = await picked.readAsBytes();
      // ignore: avoid_print
      print('[OCR] Image Size: ${bytes.length} bytes');

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      tempRef = FirebaseStorage.instance.ref().child('ocr_temp/$fileName');

      await tempRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final imageUrl = await tempRef.getDownloadURL();
      // ignore: avoid_print
      print('[OCR] Public URL: $imageUrl');

      // Step 1: Extract raw text from image via deepseek-ocr.
      final step1Body = jsonEncode({
        'model': 'deepseek-ocr',
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Recognize the text in the image.'},
              {
                'type': 'image_url',
                'image_url': {'url': imageUrl},
              },
            ],
          },
        ],
      });

      final res1 = await http
          .post(
            Uri.parse('https://llm.alem.ai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_kOcrApiKey',
              'Content-Type': 'application/json',
            },
            body: step1Body,
          )
          .timeout(const Duration(seconds: 60));

      // ignore: avoid_print
      print('[OCR] Step1 Status: ${res1.statusCode}');

      if (res1.statusCode != 200 || res1.body.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка OCR: ${res1.statusCode}')),
          );
        }
        return;
      }

      final data1 = jsonDecode(res1.body) as Map<String, dynamic>;
      final extractedText =
          (data1['choices']?[0]?['message']?['content'] ?? '') as String;
      // ignore: avoid_print
      print('[OCR] Step1 Text: $extractedText');

      if (extractedText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось распознать текст')),
          );
        }
        return;
      }

      // Step 2: Analyze extracted text via gemma3.
      const analysisPrompt =
          'You analyze a photo of a cosmetic product. Your task: '
          '1. Determine the product name accurately. '
          '2. Determine the product category strictly from this list: '
          'Cleansing, Serum, SPF, Toner, Actives, Mask, Moisturizing.\n\n'
          'Category determination rules: '
          'Cleansing (gels, foams, cleanser), '
          'Serum (serum, essence, ampoule), '
          'SPF (sunscreen, fluids), '
          'Toner (toner, lotion, tonic), '
          'Actives (retinol, acids, vitamin C), '
          'Mask (mask, clay mask), '
          'Moisturizing (creams, fluids, moisturizers).\n\n'
          'The response must be strictly in the format:\n'
          'Name: <product name>\n'
          'Category: <one category from the list>';

      final step2Body = jsonEncode({
        'model': 'gemma3',
        'messages': [
          {
            'role': 'user',
            'content':
                'Text from the product: $extractedText\n\n$analysisPrompt',
          },
        ],
      });

      final res2 = await http
          .post(
            Uri.parse('https://llm.alem.ai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_kGemmmaApiKey',
              'Content-Type': 'application/json',
            },
            body: step2Body,
          )
          .timeout(const Duration(seconds: 60));

      // ignore: avoid_print
      print('[OCR] Step2 Status: ${res2.statusCode}');
      // ignore: avoid_print
      print('[OCR] Step2 Raw Output: ${res2.body}');

      if (res2.statusCode != 200 || res2.body.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка анализа: ${res2.statusCode}')),
          );
        }
        return;
      }

      final data2 = jsonDecode(res2.body) as Map<String, dynamic>;
      // ignore: avoid_print
      print('[OCR] Step2 Tokens: ${data2['usage']?['total_tokens']}');

      final content =
          (data2['choices']?[0]?['message']?['content'] ?? '') as String;

      if (content.isNotEmpty && mounted) _applyOcrResult(content);
    } catch (e) {
      // ignore: avoid_print
      print('[OCR] Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Произошла ошибка. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      // Delay cleanup to ensure the file is available for both API steps.
      Future.delayed(const Duration(seconds: 15), () {
        tempRef?.delete().catchError(
          (Object e) => print('[OCR] Temp cleanup failed: $e'),
        );
      });

      if (_ocrLoading && mounted) setState(() => _ocrLoading = false);
    }
  }

  void _applyOcrResult(String content) {
    final nameMatch = RegExp(
      r'Name:\s*(.*)',
      caseSensitive: false,
    ).firstMatch(content);
    final categoryMatch = RegExp(
      r'Category:\s*(.*)',
      caseSensitive: false,
    ).firstMatch(content);

    final extractedName = nameMatch?.group(1)?.trim();
    final extractedCategory = categoryMatch?.group(1)?.trim();

    if (extractedName == null || extractedName.isEmpty) {
      // ignore: avoid_print
      print('[OCR] Parsing failed for body: $content');
    }

    // ignore: avoid_print
    print('[OCR] Extracted Name: $extractedName');
    // ignore: avoid_print
    print('[OCR] Extracted Category: $extractedCategory');

    // Map English category labels from gemma3 response to Russian app categories.
    const categoryMap = {
      'Cleansing': 'Очищение',
      'Serum': 'Сыворотка',
      'SPF': 'SPF',
      'Toner': 'Тоник',
      'Actives': 'Актив',
      'Mask': 'Маска',
      'Moisturizing': 'Увлажнение',
    };
    String? matchedCategory;
    if (extractedCategory != null && extractedCategory.isNotEmpty) {
      final russian = categoryMap[extractedCategory];
      matchedCategory = russian != null ? russian : 'Увлажнение'; // fallback
    }

    // ignore: avoid_print
    print('[OCR] Matched Category: $matchedCategory');

    // Clear loading atomically with field assignment so the UI
    // never shows a brief enabled-but-empty state.
    setState(() {
      _ocrLoading = false;
      if (extractedName != null && extractedName.isNotEmpty) {
        _nameController.text = extractedName;
      }
      if (matchedCategory != null) {
        _selectedCategory = matchedCategory;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final systemBottom = MediaQuery.paddingOf(context).bottom;

    return Listener(
      // Raw pointer events — does not participate in the gesture arena, so it
      // does not conflict with the inner SingleChildScrollView. When the scroll
      // is at the very top and the user drags down far enough, pop the sheet.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _dragStartY = event.position.dy;
        _canDismiss = !_scrollController.hasClients ||
            _scrollController.position.pixels <= 0;
      },
      onPointerMove: (event) {
        if (!_canDismiss) return;
        if (event.position.dy - _dragStartY > 80) {
          _canDismiss = false;
          Navigator.of(context).maybePop();
        }
      },
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _save();
        },
        child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(w * 0.061)),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(
            left: w * 0.051,
            right: w * 0.051,
            top: w * 0.031,
            bottom: w * 0.051 + bottomInset + systemBottom,
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
                  SizedBox(width: w * 0.020),
                  _FillByPhotoButton(
                    w: w,
                    onTap: _ocrLoading ? null : _fillByPhoto,
                    isLoading: _ocrLoading,
                  ),
                  SizedBox(width: w * 0.020),
                  GestureDetector(
                    onTap: _discard,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      Icons.close,
                      size: w * 0.051,
                      color: AppColors.primaryMedium,
                    ),
                  ),
                ],
              ),
              SizedBox(height: w * 0.051),

              // ── Form body — disabled while OCR is running ────────────────
              AbsorbPointer(
                absorbing: _ocrLoading,
                child: AnimatedOpacity(
                  opacity: _ocrLoading ? 0.45 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Photo preview ──────────────────────────────────────
                      if (_photo != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(w * 0.038),
                          child: kIsWeb
                              ? Image.network(
                                  _photo!.path,
                                  height: w * 0.46,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_photo!.path),
                                  height: w * 0.46,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        SizedBox(height: w * 0.031),
                      ] else if (widget.initialProduct?.photoUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(w * 0.038),
                          child: Image.network(
                            widget.initialProduct!.photoUrl!,
                            height: w * 0.46,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        SizedBox(height: w * 0.031),
                      ],

                      // ── Name field ─────────────────────────────────────────
                      _InputField(
                        controller: _nameController,
                        label: 'Название',
                        hint: 'Введите название...',
                      ),
                      SizedBox(height: w * 0.041),

                      // ── Category chips ─────────────────────────────────────
                      Text('Категория', style: _scheduleHeaderStyle),
                      SizedBox(height: w * 0.020),
                      _CategoryChips(
                        categories: _categories,
                        selected: _selectedCategory,
                        onSelect: (cat) => setState(
                          () => _selectedCategory = _selectedCategory == cat
                              ? null
                              : cat,
                        ),
                        w: w,
                      ),
                      SizedBox(height: w * 0.041),

                      // ── Schedule section ───────────────────────────────────
                      Text('График использования', style: _scheduleHeaderStyle),
                      SizedBox(height: w * 0.031),
                      _DaySelector(
                        selectedDays: _selectedDays,
                        onToggle: (i) => setState(
                          () => _selectedDays[i] = !_selectedDays[i],
                        ),
                      ),
                      SizedBox(height: w * 0.041),

                      // ── Add photo button ───────────────────────────────────
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
                              (_photo != null ||
                                      widget.initialProduct?.photoUrl != null)
                                  ? 'Изменить фото продукта'
                                  : 'Добавить фото продукта',
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
            ],
          ),
        ),
      ),
    ));
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

const TextStyle _scheduleHeaderStyle = TextStyle(
  fontFamily: 'SF Pro',
  fontSize: 16,
  fontWeight: FontWeight.w300,
  color: AppColors.primaryDark,
  letterSpacing: -0.5,
  height: 1.25,
);

// ─── "Заполнить по фото" pill — golden gradient with loading state ────────────

class _FillByPhotoButton extends StatelessWidget {
  const _FillByPhotoButton({
    required this.w,
    required this.onTap,
    required this.isLoading,
  });

  final double w;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
            if (isLoading)
              SizedBox(
                width: w * 0.038,
                height: w * 0.038,
                child: const CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white,
                ),
              )
            else
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
