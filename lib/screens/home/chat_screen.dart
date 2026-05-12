import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../providers/chat_provider.dart';
import '../../services/stt_service.dart';
import '../../widgets/breathing_mic_button.dart';
import '../../widgets/dismiss_keyboard.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final SttService _stt = SttService();
  bool _showMic = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? overrideText]) async {
    final text = (overrideText ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    if (mounted) setState(() => _showMic = false);
    final chat = context.read<ChatProvider>();
    await chat.sendMessage(text);
    if (chat.error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(chat.error!)));
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _newChat() async {
    HapticFeedback.selectionClick();
    // Close the conversation drawer if it happens to be open, otherwise
    // this is a harmless no-op.
    Navigator.of(context).maybePop();
    await context.read<ChatProvider>().startNewConversation();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    _scrollToEnd();

    return Scaffold(
      drawer: _ConversationDrawer(onNewChat: _newChat),
      appBar: AppBar(
        title: Text(
          chat.current?.title ?? 'New chat',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _newChat,
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: DismissKeyboard(
        child: Column(
        children: [
          Expanded(
            child: chat.messages.isEmpty
                ? _EmptyChat(hasConversation: chat.current != null)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: chat.messages.length,
                    itemBuilder: (_, i) =>
                        _Bubble(message: chat.messages[i]),
                  ),
          ),
          if (chat.sending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: _TypingIndicator(),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showMic
                ? Padding(
                    key: const ValueKey('mic'),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: BreathingMicButton(
                        stt: _stt,
                        onPartial: (p) => _input.text = p,
                        onFinal: (t) {
                          _input.text = t;
                          setState(() => _showMic = false);
                        },
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-mic')),
          ),
          _InputBar(
            controller: _input,
            onSend: _send,
            onToggleMic: () {
              HapticFeedback.selectionClick();
              setState(() => _showMic = !_showMic);
            },
            micActive: _showMic,
          ),
        ],
      ),
      ),
    );
  }
}

class _ConversationDrawer extends StatelessWidget {
  const _ConversationDrawer({required this.onNewChat});
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final fmt = DateFormat('MMM d');
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Text('Chats',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: onNewChat,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New chat'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: chat.conversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No conversations yet.\nStart a new chat above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: chat.conversations.length,
                      itemBuilder: (_, i) {
                        final c = chat.conversations[i];
                        final selected = chat.current?.id == c.id;
                        return _ConversationTile(
                          conversation: c,
                          selected: selected,
                          subtitle: fmt.format(c.lastMessageAt),
                          onSelect: () {
                            context.read<ChatProvider>().selectConversation(c);
                            Navigator.of(context).pop();
                          },
                          onRename: () =>
                              _promptRename(context, c),
                          onDelete: () =>
                              _confirmDelete(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptRename(BuildContext context, Conversation c) async {
    final ctrl = TextEditingController(text: c.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty && context.mounted) {
      await context
          .read<ChatProvider>()
          .renameConversation(c.id, newTitle);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Conversation c) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text('"${c.title}" will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      await context.read<ChatProvider>().deleteConversation(c.id);
    }
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.subtitle,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  final Conversation conversation;
  final bool selected;
  final String subtitle;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor:
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
      leading: const Icon(Icons.chat_bubble_outline),
      title: Text(
        conversation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: selected ? FontWeight.w600 : null),
      ),
      subtitle: Text(
        conversation.lastMessagePreview ?? subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (v) {
          if (v == 'rename') onRename();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
      onTap: onSelect,
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.hasConversation});
  final bool hasConversation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            hasConversation
                ? 'Send the first message'
                : 'Say hi to Personal Buddy',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Ask anything, plan your day, or just chat.\nUse the mic for voice input.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isUser ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SelectableText(
            message.text,
            style: TextStyle(color: _isUser ? Colors.white : null),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Text('Personal Buddy is typing…',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onToggleMic,
    required this.micActive,
  });

  final TextEditingController controller;
  final void Function() onSend;
  final void Function() onToggleMic;
  final bool micActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(micActive ? Icons.keyboard : Icons.mic_none),
              tooltip: micActive ? 'Hide mic' : 'Voice input',
              onPressed: onToggleMic,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Shortcuts(
                shortcuts: <ShortcutActivator, Intent>{
                  LogicalKeySet(LogicalKeyboardKey.enter):
                      const _SendIntent(),
                  LogicalKeySet(LogicalKeyboardKey.shift,
                          LogicalKeyboardKey.enter):
                      const DoNothingAndStopPropagationIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    _SendIntent: CallbackAction<_SendIntent>(
                      onInvoke: (_) {
                        onSend();
                        return null;
                      },
                    ),
                  },
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: 'Message Personal Buddy…  (Enter to send)',
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.cancel, size: 20),
                                onPressed: () {
                                  controller.clear();
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _SendIntent extends Intent {
  const _SendIntent();
}
