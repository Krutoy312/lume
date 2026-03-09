import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/chat_controller.dart';

/// The bottom input area: optional menu panel + optional mode chip + input row.
class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({super.key, required this.onSend});

  final void Function(String text) onSend;

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    widget.onSend(_controller.text);
    _controller.clear();
    setState(() {}); // rebuild to update send button state
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoSourceSheet(w: MediaQuery.sizeOf(context).width),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      ref.read(chatProvider.notifier).setPhoto(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Disclaimer
        Padding(
          padding: EdgeInsets.only(bottom: w * 0.020),
          child: Text(
            'Ответы носят рекомендательный характер и не являются медицинскими советами.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: w * 0.020,
              fontWeight: FontWeight.w300,
              color: AppColors.primaryMedium,
              letterSpacing: -0.5,
            ),
          ),
        ),

        // ── Menu panel (animated) ─────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: state.menuOpen
              ? _MenuPanel(
                  selectedMode: state.selectedMode,
                  onSelect: notifier.selectMode,
                  w: w,
                )
              : const SizedBox.shrink(),
        ),

        // ── Photo thumbnail strip ─────────────────────────────────────────
        if (state.attachedPhoto != null)
          _PhotoStrip(
            photo: state.attachedPhoto!,
            onRemove: ref.read(chatProvider.notifier).removePhoto,
            w: w,
          ),

        // ── Input container ───────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.051),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F8B7355),
                  blurRadius: 32,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mode chip (only when a mode is active)
                if (state.selectedMode != ChatMode.none)
                  _ModeChip(
                    label: state.selectedMode.label,
                    onDismiss: notifier.clearMode,
                    w: w,
                  ),
                // Input row
                _InputRow(
                  controller: _controller,
                  state: state,
                  onMenuTap: notifier.toggleMenu,
                  onAttachTap: _pickPhoto,
                  onSend: _send,
                  w: w,
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: w * 0.025),
      ],
    );
  }
}

// ─── Menu panel ───────────────────────────────────────────────────────────────

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({
    required this.selectedMode,
    required this.onSelect,
    required this.w,
  });

  final ChatMode selectedMode;
  final void Function(ChatMode) onSelect;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: w * 0.051,
        right: w * 0.051,
        bottom: w * 0.025,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F8B7355),
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: EdgeInsets.all(w * 0.038),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuItem(
              label: 'Анализ кожи по фото',
              mode: ChatMode.skinPhoto,
              selectedMode: selectedMode,
              onTap: () => onSelect(ChatMode.skinPhoto),
              w: w,
            ),
            SizedBox(height: w * 0.020),
            _MenuItem(
              label: 'Анализ средства по фото',
              mode: ChatMode.productPhoto,
              selectedMode: selectedMode,
              onTap: () => onSelect(ChatMode.productPhoto),
              w: w,
            ),
            SizedBox(height: w * 0.020),
            _MenuItem(
              label: 'Подобрать уход',
              mode: ChatMode.routinePick,
              selectedMode: selectedMode,
              onTap: () => onSelect(ChatMode.routinePick),
              w: w,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.mode,
    required this.selectedMode,
    required this.onTap,
    required this.w,
  });

  final String label;
  final ChatMode mode;
  final ChatMode selectedMode;
  final VoidCallback onTap;
  final double w;

  bool get _isSelected => mode == selectedMode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: w * 0.061, // 24px on 393px screen
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: _isSelected
              ? const LinearGradient(
                  colors: [AppColors.golden, AppColors.goldenLighter],
                )
              : null,
          border: _isSelected
              ? null
              : Border.all(color: const Color(0xFFF7F7F7), width: 1),
          borderRadius: BorderRadius.circular(25),
        ),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: w * 0.038),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontSize: w * 0.031,
            fontWeight: _isSelected ? FontWeight.w600 : FontWeight.w300,
            color: _isSelected ? AppColors.surface : AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

// ─── Mode chip ────────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.onDismiss,
    required this.w,
  });

  final String label;
  final VoidCallback onDismiss;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: w * 0.020,
        left: w * 0.041,
        right: w * 0.041,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: w * 0.066,
          padding: EdgeInsets.symmetric(horizontal: w * 0.038),
          decoration: BoxDecoration(
            color: AppColors.progressBarBack,
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: w * 0.031,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryDark,
                  height: 1.0,
                ),
              ),
              SizedBox(width: w * 0.020),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(
                  Icons.close,
                  size: w * 0.033,
                  color: AppColors.primaryMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Input row ────────────────────────────────────────────────────────────────

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.state,
    required this.onMenuTap,
    required this.onAttachTap,
    required this.onSend,
    required this.w,
  });

  final TextEditingController controller;
  final ChatState state;
  final VoidCallback onMenuTap;
  final VoidCallback onAttachTap;
  final VoidCallback onSend;
  final double w;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (_, __) {
        final canSend = state.canSend(controller.text);
        final showAttach = true;
        final attachEnabled =
            state.selectedMode.showAttach ||
            state.selectedMode == ChatMode.none;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: w * 0.038,
            vertical: w * 0.036,
          ),
          child: Row(
            children: [
              // ic_menu
              GestureDetector(
                onTap: onMenuTap,
                behavior: HitTestBehavior.opaque,
                child: SvgPicture.asset(
                  'assets/icons/ic_menu.svg',
                  width: w * 0.046,
                  height: w * 0.046,
                ),
              ),
              SizedBox(width: w * 0.025),

              // Text field
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: w * 0.031,
                    fontWeight: FontWeight.w400,
                    color: AppColors.primaryDark,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Сообщение...',
                    hintStyle: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: w * 0.031,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFA7947F),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),

              SizedBox(width: w * 0.020),

              // ic_attach (conditionally shown)
              if (showAttach)
                GestureDetector(
                  onTap: attachEnabled ? onAttachTap : null,
                  behavior: HitTestBehavior.opaque,
                  child: Opacity(
                    opacity: attachEnabled ? 1.0 : 0.35,
                    child: SvgPicture.asset(
                      'assets/icons/ic_attach.svg',
                      width: w * 0.046,
                      height: w * 0.046,
                    ),
                  ),
                ),

              SizedBox(width: w * 0.015),

              // ic_send
              GestureDetector(
                onTap: canSend ? onSend : null,
                behavior: HitTestBehavior.opaque,
                child: Opacity(
                  opacity: canSend ? 1.0 : 0.35,
                  child: SvgPicture.asset(
                    'assets/icons/ic_send.svg',
                    width: w * 0.046,
                    height: w * 0.046,
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

// ─── Photo thumbnail strip ────────────────────────────────────────────────────

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photo,
    required this.onRemove,
    required this.w,
  });

  final XFile photo;
  final VoidCallback onRemove;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: w * 0.051,
        right: w * 0.051,
        bottom: w * 0.020,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: kIsWeb
                    ? Image.network(
                        photo.path,
                        width: w * 0.153,
                        height: w * 0.153,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(photo.path),
                        width: w * 0.153,
                        height: w * 0.153,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: w * 0.051,
                    height: w * 0.051,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xCC000000),
                    ),
                    child: Icon(
                      Icons.close,
                      size: w * 0.030,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Photo source picker sheet ────────────────────────────────────────────────

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        w * 0.051,
        0,
        w * 0.051,
        w * 0.051 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F8B7355),
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Выбрать из галереи',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
              w: w,
              topRadius: true,
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.scaffoldBackground,
              indent: w * 0.051,
            ),
            _SourceTile(
              icon: Icons.camera_alt_outlined,
              label: 'Сделать фото',
              onTap: () => Navigator.pop(context, ImageSource.camera),
              w: w,
              bottomRadius: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.w,
    this.topRadius = false,
    this.bottomRadius = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double w;
  final bool topRadius;
  final bool bottomRadius;

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(20);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.only(
        topLeft: topRadius ? radius : Radius.zero,
        topRight: topRadius ? radius : Radius.zero,
        bottomLeft: bottomRadius ? radius : Radius.zero,
        bottomRight: bottomRadius ? radius : Radius.zero,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.051,
          vertical: w * 0.043,
        ),
        child: Row(
          children: [
            Icon(icon, size: w * 0.056, color: AppColors.golden),
            SizedBox(width: w * 0.038),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: w * 0.036,
                fontWeight: FontWeight.w400,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
