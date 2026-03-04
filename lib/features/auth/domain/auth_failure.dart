/// Typed auth error surfaced to the UI.
/// All user-facing strings are in Russian to match the app locale.
class AuthFailure {
  const AuthFailure(this.message);

  final String message;

  // ── Named constructors ──────────────────────────────────────────────────────

  static const AuthFailure cancelled = AuthFailure('Вход отменён.');
  static const AuthFailure unknown = AuthFailure('Неизвестная ошибка. Попробуйте снова.');
  static const AuthFailure appleNotSupported =
      AuthFailure('Apple Sign-In доступен только на iOS.');
  static const AuthFailure nameCooldown =
      AuthFailure('Изменить имя можно только раз в 2 недели.');
  static const AuthFailure requiresRecentLogin =
      AuthFailure('Выйдите и войдите снова, затем повторите попытку.');

  /// Maps a [FirebaseAuthException.code] to a human-readable message.
  factory AuthFailure.fromFirebaseCode(String code) {
    return switch (code) {
      'account-exists-with-different-credential' =>
        const AuthFailure('Аккаунт уже существует с другим способом входа.'),
      'invalid-credential' =>
        const AuthFailure('Неверные данные для входа. Попробуйте снова.'),
      'user-disabled' =>
        const AuthFailure('Аккаунт заблокирован. Обратитесь в поддержку.'),
      'network-request-failed' =>
        const AuthFailure('Нет соединения с интернетом.'),
      'too-many-requests' =>
        const AuthFailure('Слишком много попыток. Попробуйте позже.'),
      'operation-not-allowed' =>
        const AuthFailure('Этот способ входа отключён.'),
      'requires-recent-login' => AuthFailure.requiresRecentLogin,
      _ => AuthFailure.unknown,
    };
  }

  @override
  String toString() => 'AuthFailure($message)';
}
