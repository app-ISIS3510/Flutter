class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String? pendingEmail;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.pendingEmail,
  });
}
