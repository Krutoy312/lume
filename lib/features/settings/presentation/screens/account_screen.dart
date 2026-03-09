import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/auth_failure.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/account_arrow_icon.dart';
import '../widgets/account_delete_row.dart';
import '../widgets/account_notifications_toggle.dart';
import '../widgets/account_section_label.dart';
import '../widgets/account_settings_card.dart';
import '../widgets/care_time_bottom_sheet.dart';
import '../widgets/edit_name_bottom_sheet.dart';
import '../widgets/goal_bottom_sheet.dart';
import '../widgets/skin_type_bottom_sheet.dart';

/// Account & settings screen.
///
/// Acts as a pure container: it owns the reactive state (notifications toggle,
/// Firestore sync flag) and auth actions (sign-out, delete account), then
/// assembles the layout from the widgets in the `widgets/` directory.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _notificationsEnabled = true;
  bool _syncedFromDb = false;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final userDocAsync = ref.watch(userDocumentProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: userDocAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.golden,
              strokeWidth: 2,
            ),
          ),
          error: (_, __) => _buildBody(context, w, null),
          data: (snapshot) => _buildBody(context, w, snapshot?.data()),
        ),
      ),
    );
  }

  // ── Layout ──────────────────────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    double w,
    Map<String, dynamic>? data,
  ) {
    _syncNotificationsToggle(data);

    final name = data?['name'] as String?;
    final skinType = data?['skinType'] as String?;
    final goal = data?['goal'] as String?;
    final timeLabel = _resolveTimeLabel(data);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        w * 0.051, // 20 px
        w * 0.135, // 53 px top — matches Figma
        w * 0.051,
        w * 0.061,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Профиль ─────────────────────────────────────────────────────────
          AccountSectionLabel('Профиль'),
          SizedBox(height: 12),
          AccountSettingsCard(
            w: w,
            rows: [
              AccountRowData(
                icon: 'assets/icons/ic_person.svg',
                title: 'Имя',
                subtitle: name ?? 'Введите имя',
                trailing: AccountArrowIcon(w: w),
                onTap: () => showEditNameBottomSheet(context),
              ),
              AccountRowData(
                icon: 'assets/icons/ic_type_skin.svg',
                title: 'Тип кожи',
                // Show the Russian label when a type is saved, hint otherwise.
                subtitle: skinTypeLabel(skinType) ?? 'Выберите тип кожи',
                trailing: AccountArrowIcon(w: w),
                onTap: () =>
                    showSkinTypeBottomSheet(context, currentSkinType: skinType),
              ),
              AccountRowData(
                icon: 'assets/icons/ic_goal.svg',
                title: 'Цель',
                subtitle: goalLabel(goal) ?? 'Выберите цель',
                trailing: AccountArrowIcon(w: w),
                onTap: () => showGoalBottomSheet(context, currentGoal: goal),
              ),
            ],
          ),
          SizedBox(height: 24),

          // ── Настройки приложения ─────────────────────────────────────────────
          AccountSectionLabel('Настройки приложения'),
          SizedBox(height: 12),
          AccountSettingsCard(
            w: w,
            rows: [
              AccountRowData(
                icon: 'assets/icons/ic_remind.svg',
                title: 'Напоминать об уходе в:',
                subtitle: timeLabel.isNotEmpty ? timeLabel : '8:00 – 21:00',
                trailing: AccountArrowIcon(w: w),
                onTap: () => showCareTimeBottomSheet(
                  context,
                  // Pass current Firestore values so the pickers are pre-filled.
                  morningMinutes: data?['morningMinutes'] as int?,
                  eveningMinutes: data?['eveningMinutes'] as int?,
                ),
              ),
              AccountRowData(
                icon: 'assets/icons/ic_notification.svg',
                title: 'Получать уведомления\nоб уходе',
                trailing: AccountNotificationsToggle(
                  value: _notificationsEnabled,
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          // ── Обратная связь ───────────────────────────────────────────────────
          AccountSectionLabel('Обратная связь'),
          SizedBox(height: 12),
          AccountSettingsCard(
            w: w,
            rows: [
              AccountRowData(
                icon: 'assets/icons/ic_letter.svg',
                title: 'Сообщить о проблеме',
                trailing: AccountArrowIcon(w: w),
                onTap: () {},
              ),
              AccountRowData(
                icon: 'assets/icons/ic_light_bulb.svg',
                title: 'Предложить идею',
                trailing: AccountArrowIcon(w: w),
                onTap: () {},
              ),
            ],
          ),
          SizedBox(height: w * 0.061),

          // ── Политика конфиденциальности ──────────────────────────────────────
          AccountSettingsCard(
            w: w,
            rows: [
              AccountRowData(
                icon: 'assets/icons/ic_attention.svg',
                title: 'Политика конфиденциальности',
                onTap: () {},
              ),
            ],
          ),
          SizedBox(height: w * 0.061),

          // ── Выйти из аккаунта ────────────────────────────────────────────────
          AccountSettingsCard(
            w: w,
            rows: [
              AccountRowData(
                icon: 'assets/icons/ic_leave.svg',
                title: 'Выйти из аккаунта',
                onTap: _signOut,
              ),
            ],
          ),
          SizedBox(height: w * 0.031),

          // ── Удалить аккаунт ──────────────────────────────────────────────────
          AccountDeleteRow(w: w, onTap: _deleteAccount),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Syncs [_notificationsEnabled] from the Firestore document exactly once.
  void _syncNotificationsToggle(Map<String, dynamic>? data) {
    if (_syncedFromDb || data == null) return;
    _syncedFromDb = true;
    final dbVal = data['notificationsEnabled'] as bool?;
    if (dbVal != null && dbVal != _notificationsEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _notificationsEnabled = dbVal);
      });
    }
  }

  /// Returns "HH:MM – HH:MM" from Firestore time fields.
  /// Accepts either String values ("9:00") or int minute-of-day values (540).
  String _resolveTimeLabel(Map<String, dynamic>? data) {
    if (data == null) return '';
    final m =
        data['morningTime'] as String? ??
        _minutesToTime(data['morningMinutes'] as int?);
    final e =
        data['eveningTime'] as String? ??
        _minutesToTime(data['eveningMinutes'] as int?);
    if (m == null && e == null) return '';
    return '${m ?? '--:--'} – ${e ?? '--:--'}';
  }

  String? _minutesToTime(int? minutes) {
    if (minutes == null) return null;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final ok = await _confirm(
      title: 'Выйти из аккаунта?',
      body: 'Вы вернётесь на экран входа.',
      confirmText: 'Выйти',
    );
    if (!ok || !mounted) return;
    await ref.read(authControllerProvider.notifier).signOut();
  }

  Future<void> _deleteAccount() async {
    final ok = await _confirm(
      title: 'Удалить аккаунт?',
      body: 'Все ваши данные будут удалены без возможности восстановления.',
      confirmText: 'Удалить',
      destructive: true,
    );
    if (!ok || !mounted) return;

    await ref.read(authControllerProvider.notifier).deleteAccount();
    if (!mounted) return;

    // On success: GoRouter's _GoRouterRefreshStream detects authStateChanges(null)
    // and automatically redirects to /login — no explicit navigation needed.
    final authState = ref.read(authControllerProvider);
    if (authState is AsyncError) {
      final failure = authState.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure is AuthFailure
                ? failure.message
                : 'Не удалось удалить аккаунт. Выйдите и войдите снова, затем повторите попытку.',
          ),
        ),
      );
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmText,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: AppTextStyles.rowTitle),
        content: Text(body, style: AppTextStyles.rowCaption),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Отмена',
              style: AppTextStyles.rowTitle.copyWith(
                color: AppColors.primaryMedium,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmText,
              style: AppTextStyles.rowTitle.copyWith(
                color: destructive ? AppColors.alertRed : AppColors.golden,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
