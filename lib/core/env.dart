import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get anthropicApiKey {
    final v = dotenv.maybeGet('ANTHROPIC_API_KEY') ?? '';
    if (v.isEmpty) {
      throw StateError(
        'ANTHROPIC_API_KEY is missing from .env. Copy .env.example to .env '
        'and fill in your key from https://console.anthropic.com/',
      );
    }
    return v;
  }

  static String get anthropicModel =>
      dotenv.maybeGet('ANTHROPIC_MODEL') ?? 'claude-sonnet-4-6';
}
