import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../services/claude_chat_service.dart';
import '../services/firestore_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({required this.uid}) {
    _convSub = _cloud.watchConversations(uid).listen(_onConversationsUpdate);
  }

  final String uid;
  final FirestoreService _cloud = FirestoreService.instance;
  final ClaudeChatService _claude = ClaudeChatService();

  StreamSubscription<List<Conversation>>? _convSub;
  StreamSubscription<List<ChatMessage>>? _msgSub;

  List<Conversation> _conversations = const [];
  Conversation? _current;
  List<ChatMessage> _messages = const [];
  bool _sending = false;
  String? _error;

  List<Conversation> get conversations => _conversations;
  Conversation? get current => _current;
  List<ChatMessage> get messages => _messages;
  bool get sending => _sending;
  String? get error => _error;
  bool get hasConversation => _current != null;

  void _onConversationsUpdate(List<Conversation> list) {
    _conversations = list;
    // If the currently active conversation has been removed somewhere else
    // (for example, from the drawer's delete action), clear the local state
    // so the UI doesn't keep pointing at a document that no longer exists.
    if (_current != null && !list.any((c) => c.id == _current!.id)) {
      _current = null;
      _messages = const [];
      _msgSub?.cancel();
    }
    // When nothing is selected yet but conversations exist, automatically
    // open the most recently active one so the chat screen never lands on
    // an empty state when there's content to show.
    if (_current == null && list.isNotEmpty) {
      selectConversation(list.first);
      return;
    }
    notifyListeners();
  }

  void selectConversation(Conversation c) {
    if (_current?.id == c.id) return;
    _current = c;
    _messages = const [];
    _error = null;
    _msgSub?.cancel();
    _msgSub = _cloud
        .watchMessages(uid: uid, conversationId: c.id)
        .listen((m) {
      _messages = m;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> startNewConversation() async {
    final c = await _cloud.createConversation(uid: uid);
    selectConversation(c);
  }

  Future<void> deleteConversation(String conversationId) async {
    final wasCurrent = _current?.id == conversationId;
    await _cloud.deleteConversation(uid: uid, conversationId: conversationId);
    if (wasCurrent) {
      _current = null;
      _messages = const [];
      _msgSub?.cancel();
      notifyListeners();
    }
  }

  Future<void> renameConversation(
      String conversationId, String title) async {
    await _cloud.renameConversation(
        uid: uid, conversationId: conversationId, title: title);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Create a conversation document on demand the first time the user
    // sends a message. This avoids littering Firestore with empty threads
    // every time someone taps "New chat" but then changes their mind.
    if (_current == null) {
      _current = await _cloud.createConversation(
        uid: uid,
        title: _autoTitle(trimmed),
      );
      _msgSub?.cancel();
      _msgSub = _cloud
          .watchMessages(uid: uid, conversationId: _current!.id)
          .listen((m) {
        _messages = m;
        notifyListeners();
      });
    }
    final conversationId = _current!.id;

    _sending = true;
    _error = null;
    notifyListeners();

    try {
      await _cloud.addMessage(
        uid: uid,
        conversationId: conversationId,
        role: MessageRole.user,
        text: trimmed,
      );

      // Once the conversation has its first real message, swap the
      // placeholder "New chat" title for a snippet of what the user just
      // wrote. This gives every entry in the drawer a recognizable label.
      if (_current!.title == 'New chat') {
        final newTitle = _autoTitle(trimmed);
        await _cloud.renameConversation(
            uid: uid, conversationId: conversationId, title: newTitle);
      }

      final history = [
        ..._messages,
        ChatMessage(
          id: 'pending',
          role: MessageRole.user,
          text: trimmed,
          createdAt: DateTime.now(),
        ),
      ];

      final reply = await _claude.assistantChat(history: history);
      await _cloud.addMessage(
        uid: uid,
        conversationId: conversationId,
        role: MessageRole.assistant,
        text:
            reply.isEmpty ? 'Sorry — I couldn\'t come up with a reply.' : reply,
      );
    } catch (e) {
      _error = _humanize(e);
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  String _autoTitle(String firstMessage) {
    final clean = firstMessage.replaceAll('\n', ' ').trim();
    if (clean.length <= 40) return clean;
    return '${clean.substring(0, 40)}…';
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
    _convSub?.cancel();
    _msgSub?.cancel();
    _claude.dispose();
    super.dispose();
  }
}
