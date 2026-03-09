import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Fixed top bar: character avatar + "Lume" title + "AI-ассистент" subtitle.
///
/// Expands vertically to accommodate the system status bar so the image is
/// never clipped on any device.
class ChatAppBar extends StatelessWidget {
  const ChatAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final topPad = MediaQuery.paddingOf(context).top;
    // Avatar diameter + vertical padding on each side.
    final avatarSize = w * 0.107;
    final vertPad = w * 0.025;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
        w * 0.051,
        topPad + vertPad,
        w * 0.051,
        vertPad,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Character avatar circle — sized and clipped to never overflow.
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.progressBarBack,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/img_character_chat.png',
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: w * 0.030),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lume',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: w * 0.041,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                  height: 1.25,
                ),
              ),
              Text(
                'AI-ассистент',
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  fontSize: w * 0.031,
                  fontWeight: FontWeight.w400,
                  color: AppColors.primaryMedium,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
