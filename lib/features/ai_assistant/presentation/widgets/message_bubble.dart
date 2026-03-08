import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/chat_message.dart';

/// A single chat bubble — right-aligned for user, left-aligned for AI.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  bool get _isUser => message.role == ChatRole.user;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: w * 0.75),
        margin: EdgeInsets.symmetric(
          horizontal: w * 0.051,
          vertical: w * 0.015,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.038,
          vertical: w * 0.028,
        ),
        decoration: BoxDecoration(
          color: _isUser ? AppColors.progressBarBack : AppColors.surface,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontSize: w * 0.036,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryDark,
            letterSpacing: -0.5,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

/// Small centered date separator pill, e.g. "Сегодня".
class DateDivider extends StatelessWidget {
  const DateDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: w * 0.025),
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.041,
          vertical: w * 0.015,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFEFDFC),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x148B7355),
              blurRadius: 16.4,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontSize: w * 0.031,
            fontWeight: FontWeight.w400,
            color: AppColors.primaryMedium,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// Typing indicator — three animated dots.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: w * 0.051,
          vertical: w * 0.015,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.038,
          vertical: w * 0.028,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final offset = ((_controller.value - i * 0.18) % 1.0);
                final scale = offset < 0.5
                    ? 0.7 + 0.6 * (offset / 0.5)
                    : 1.3 - 0.6 * ((offset - 0.5) / 0.5);
                return Transform.scale(
                  scale: scale.clamp(0.7, 1.3),
                  child: Container(
                    width: w * 0.018,
                    height: w * 0.018,
                    margin: EdgeInsets.only(right: i < 2 ? w * 0.015 : 0),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryLighter,
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
