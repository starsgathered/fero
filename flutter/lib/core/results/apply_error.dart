/// --- ApplyError ---
/// Detailed info about why applying an item failed
class ApplyError {
  /// Error message or exception details
  final String message;

  /// Optional code for categorization
  final String? code;

  ApplyError({
    required this.message,
    this.code,
  });
}
