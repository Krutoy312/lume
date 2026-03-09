import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/chat_message.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(String text) {
    ref.read(chatProvider.notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    // Scroll to bottom whenever a new message arrives or loading state changes.
    ref.listen(chatProvider, (_, next) {
      if (next.messages.length != state.messages.length || next.isLoading) {
        _scrollToBottom();
      }
    });

    // The nav-bar clearance comes from MainShell overriding padding.bottom.
    // The keyboard clearance comes from viewInsets.bottom.
    // We take whichever is larger so the input bar is always fully visible.
    final navBarPad = MediaQuery.paddingOf(context).bottom;
    final keyboardPad = MediaQuery.viewInsetsOf(context).bottom;
    final bottomInset = keyboardPad > navBarPad ? keyboardPad : navBarPad;

    return GestureDetector(
      // Dismiss menu when tapping outside.
      onTap: () {
        if (state.menuOpen) {
          ref.read(chatProvider.notifier).closeMenu();
        }
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        // Must be false: positioning is handled manually via bottomInset so
        // the body never resizes and the input bar never jumps.
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            // ── App bar ───────────────────────────────────────────────────
            const ChatAppBar(),

            // ── Messages ──────────────────────────────────────────────────
            Expanded(
              child: state.messages.isEmpty
                  ? _EmptyState()
                  : _MessageList(
                      messages: state.messages,
                      isLoading: state.isLoading,
                      scrollController: _scrollController,
                    ),
            ),

            // ── Error snackbar ────────────────────────────────────────────
            if (state.errorMessage != null)
              _ErrorBanner(
                message: state.errorMessage!,
                onDismiss: () =>
                    ref.read(chatProvider.notifier).clearError(),
              ),

            // ── Input bar ─────────────────────────────────────────────────
            // bottomInset pushes the bar above the keyboard (when open) or
            // above the floating nav bar (when closed), whichever is taller.
            Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: ChatInputBar(onSend: _handleSend),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Message list ─────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.isLoading,
    required this.scrollController,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Group messages by date to show date dividers.
    final items = _buildItems(messages);

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(top: w * 0.025, bottom: w * 0.015),
      itemCount: items.length + (isLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (isLoading && i == items.length) {
          return const TypingIndicator();
        }
        final item = items[i];
        if (item is String) return DateDivider(label: item);
        return MessageBubble(message: item as ChatMessage);
      },
    );
  }

  List<Object> _buildItems(List<ChatMessage> messages) {
    final result = <Object>[];
    String? lastDate;

    for (final msg in messages) {
      final dateLabel = _dateLabel(msg.createdAt);
      if (dateLabel != lastDate) {
        result.add(dateLabel);
        lastDate = dateLabel;
      }
      result.add(msg);
    }
    return result;
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return 'Сегодня';
    final yesterday = today.subtract(const Duration(days: 1));
    if (msgDay == yesterday) return 'Вчера';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.102),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/img_character_chat.png',
                      width: w * 0.305,
                    ),
                    SizedBox(height: w * 0.051),
                    Text(
                      'Привет! Я Lume — твой AI-ассистент по уходу за кожей.\n\nЗадай мне вопрос или выбери функцию через меню.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: w * 0.036,
                        fontWeight: FontWeight.w400,
                        color: AppColors.primaryMedium,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Container(
      color: AppColors.alertRed.withValues(alpha: 0.08),
      padding: EdgeInsets.symmetric(
        horizontal: w * 0.051,
        vertical: w * 0.020,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: w * 0.031,
                color: AppColors.alertRed,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, size: w * 0.038, color: AppColors.alertRed),
          ),
        ],
      ),
    );
  }
}
