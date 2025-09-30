
class DanmakuParseException implements Exception {
  final String message;
  final String? details;
  final dynamic originalError;

  DanmakuParseException(this.message, {this.details, this.originalError});

  @override
  String toString() {
    if (details != null) {
      return 'DanmakuParseException: $message ($details)';
    }
    return 'DanmakuParseException: $message';
  }
}