class AppConstants {
  static const appName = 'Personal Buddy';
  static const tagline = 'Your smart daily companion';

  /// The locale used by the on-device speech recognizer. We default to
  /// `en_US` because it's installed on virtually every device; the
  /// `speech_to_text` plugin will fall back to the system default if this
  /// locale happens to be missing.
  static const defaultSttLocale = 'en_US';

  /// How long a pause in speech triggers an automatic stop, in seconds.
  /// This keeps the recording session from running indefinitely when the
  /// user has finished talking.
  static const silenceTimeoutSeconds = 2;

  /// The maximum number of conversational turns we forward to Claude with
  /// each request. Trimming older turns keeps the request affordable on a
  /// pay-per-token API while still preserving useful short-term context.
  static const maxChatHistoryTurns = 12;
}

enum ChatMode {
  assistant('assistant'),
  grammar('grammar'),
  vision('vision');

  const ChatMode(this.code);
  final String code;
}
