import 'package:flutter/foundation.dart';

import '../models/message.dart';
import '../services/claude_chat_service.dart';

class GrammarProvider extends ChangeNotifier {
  final ClaudeChatService _claude = ClaudeChatService();

  String _input = '';
  GrammarCorrection? _result;
  bool _checking = false;
  String? _error;

  String get input => _input;
  GrammarCorrection? get result => _result;
  bool get checking => _checking;
  String? get error => _error;

  void setInput(String text) {
    _input = text;
  }

  Future<void> check() async {
    final text = _input.trim();
    if (text.isEmpty) return;
    _checking = true;
    _error = null;
    _result = null;
    notifyListeners();
    try {
      _result = await _claude.grammarCheck(text);
    } catch (e) {
      _error = _humanize(e);
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  void reset() {
    _input = '';
    _result = null;
    _error = null;
    notifyListeners();
  }

  String _humanize(Object e) {
    if (e is ClaudeApiException) {
      if (e.statusCode == 401) return 'Invalid Anthropic API key.';
      if (e.statusCode == 429) return 'Rate limit hit — try again in a moment.';
      return 'Claude API error (${e.statusCode}).';
    }
    return 'Something went wrong: $e';
  }

  @override
  void dispose() {
    _claude.dispose();
    super.dispose();
  }
}
