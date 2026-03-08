import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/chat_message.dart';
import '../../data/services/ai_chat_service.dart';
import '../../data/services/user_context_cache.dart';

// ─── Mode ─────────────────────────────────────────────────────────────────────

enum ChatMode { none, skinPhoto, productPhoto, routinePick }

extension ChatModeLabel on ChatMode {
  String get label => switch (this) {
        ChatMode.none => '',
        ChatMode.skinPhoto => 'Анализ кожи по фото',
        ChatMode.productPhoto => 'Анализ средства по фото',
        ChatMode.routinePick => 'Подобрать уход',
      };

  bool get requiresPhoto =>
      this == ChatMode.skinPhoto || this == ChatMode.productPhoto;

  bool get showAttach =>
      this == ChatMode.skinPhoto || this == ChatMode.productPhoto;
}

// ─── State ────────────────────────────────────────────────────────────────────

class ChatState {
  const ChatState({
    this.messages = const [],
    this.selectedMode = ChatMode.none,
    this.menuOpen = false,
    this.isLoading = false,
    this.attachedPhoto,
    this.errorMessage,
  });

  final List<ChatMessage> messages;
  final ChatMode selectedMode;
  final bool menuOpen;
  final bool isLoading;
  final XFile? attachedPhoto;
  final String? errorMessage;

  /// Whether the send button should be enabled.
  bool canSend(String inputText) {
    if (isLoading) return false;
    return switch (selectedMode) {
      ChatMode.none => inputText.trim().isNotEmpty,
      ChatMode.skinPhoto => attachedPhoto != null,
      ChatMode.productPhoto => attachedPhoto != null,
      ChatMode.routinePick => true,
    };
  }

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatMode? selectedMode,
    bool? menuOpen,
    bool? isLoading,
    XFile? attachedPhoto,
    bool clearPhoto = false,
    String? errorMessage,
    bool clearError = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        selectedMode: selectedMode ?? this.selectedMode,
        menuOpen: menuOpen ?? this.menuOpen,
        isLoading: isLoading ?? this.isLoading,
        attachedPhoto: clearPhoto ? null : (attachedPhoto ?? this.attachedPhoto),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._ref) : super(const ChatState());

  /// Riverpod Ref — used exclusively to access [userContextCacheProvider].
  final Ref _ref;

  // ── UI actions ────────────────────────────────────────────────────────────

  void toggleMenu() {
    state = state.copyWith(menuOpen: !state.menuOpen);
  }

  void closeMenu() {
    state = state.copyWith(menuOpen: false);
  }

  void selectMode(ChatMode mode) {
    state = state.copyWith(
      selectedMode: mode,
      menuOpen: false,
      clearPhoto: true, // clear previous photo when switching modes
    );
  }

  void clearMode() {
    state = state.copyWith(
      selectedMode: ChatMode.none,
      clearPhoto: true,
      clearError: true,
    );
  }

  void setPhoto(XFile photo) {
    state = state.copyWith(attachedPhoto: photo);
  }

  void removePhoto() {
    state = state.copyWith(clearPhoto: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ── Send message ──────────────────────────────────────────────────────────

  Future<void> send(String text) async {
    if (!state.canSend(text)) return;

    final trimmedText = text.trim();

    // Build the user-facing message text.
    final userDisplayText = _userDisplayText(trimmedText);

    final userMsg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: ChatRole.user,
      text: userDisplayText,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      clearError: true,
    );

    try {
      // Resolve context through the cache:
      //   Step 1+2 — notes hit  → returns immediately, zero Firestore reads.
      //   Step 3+4 — notes miss → fetches from Firestore, then stores result.
      final ctx = await _ref.read(userContextCacheProvider.notifier).getContext();
      final String reply;

      switch (state.selectedMode) {
        case ChatMode.skinPhoto:
          final url =
              await AiChatService.uploadTempImage(state.attachedPhoto!.path);
          reply = await AiChatService.sendSkinPhotoAnalysis(
            imageUrl: url,
            userText: trimmedText,
            ctx: ctx,
          );

        case ChatMode.productPhoto:
          final url =
              await AiChatService.uploadTempImage(state.attachedPhoto!.path);
          reply = await AiChatService.sendProductPhotoAnalysis(
            imageUrl: url,
            userText: trimmedText,
            ctx: ctx,
          );

        case ChatMode.routinePick:
          reply = await AiChatService.sendRoutinePick(
            userText: trimmedText,
            ctx: ctx,
          );

        case ChatMode.none:
          // Build conversation history from the existing messages.
          final history = state.messages.map((m) {
            return {
              'role': m.role == ChatRole.user ? 'user' : 'assistant',
              'content': m.text,
            };
          }).toList();
          reply = await AiChatService.sendGeneralChat(
            history: history,
            ctx: ctx,
          );
      }

      final aiMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: ChatRole.assistant,
        text: reply.trim(),
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
        clearPhoto: true, // clear after successful send in analysis modes
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось получить ответ. Попробуйте ещё раз.',
      );
    }
  }

  String _userDisplayText(String text) {
    final mode = state.selectedMode;
    if (mode == ChatMode.skinPhoto && text.isEmpty) return 'Анализ кожи по фото';
    if (mode == ChatMode.productPhoto && text.isEmpty) {
      return 'Анализ средства по фото';
    }
    if (mode == ChatMode.routinePick && text.isEmpty) return 'Подобрать уход';
    return text.isNotEmpty ? text : mode.label;
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) => ChatNotifier(ref),
);
