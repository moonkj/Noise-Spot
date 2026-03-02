class AdminConfig {
  AdminConfig._();

  /// Supabase user IDs that have admin privileges.
  /// 본인 Supabase 계정 ID로 교체하세요.
  /// (Supabase 대시보드 → Authentication → Users → 본인 row의 id 열)
  static const List<String> adminUserIds = [
    'da2a8b72-a3c2-415b-bae5-63f2fa0b92a0',
  ];

  /// Admin email for cafe request notifications.
  static const String adminEmail = 'imurmkj@gmail.com';
}
