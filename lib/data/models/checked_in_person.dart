/// Lightweight display-only model passed to [SuccessScreen].
/// Decoupled from [Member] so Google users and bulk check-ins share the same UI.
class CheckedInPerson {
  const CheckedInPerson({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  /// First word of the name — used for the headline ("Anna, you're in!").
  String get firstName => name.split(' ').first;
}
