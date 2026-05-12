import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/grammar_provider.dart';
import '../../services/stt_service.dart';
import '../../widgets/breathing_mic_button.dart';
import '../../widgets/correction_card.dart';
import '../../widgets/dismiss_keyboard.dart';

class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key});

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  final TextEditingController _input = TextEditingController();
  final SttService _stt = SttService();
  bool _showMic = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      context.read<GrammarProvider>().setInput(_input.text);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final p = context.read<GrammarProvider>();
    p.setInput(_input.text);
    FocusScope.of(context).unfocus();
    await p.check();
  }

  void _reset() {
    _input.clear();
    context.read<GrammarProvider>().reset();
    if (mounted) setState(() => _showMic = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GrammarProvider>();
    final result = p.result;
    final hasContent = _input.text.isNotEmpty || result != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grammar'),
        actions: [
          if (hasContent)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('New'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: DismissKeyboard(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hint(),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: Shortcuts(
                shortcuts: <ShortcutActivator, Intent>{
                  LogicalKeySet(LogicalKeyboardKey.enter):
                      const _CheckIntent(),
                  LogicalKeySet(LogicalKeyboardKey.shift,
                          LogicalKeyboardKey.enter):
                      const DoNothingAndStopPropagationIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    _CheckIntent: CallbackAction<_CheckIntent>(
                      onInvoke: (_) {
                        _check();
                        return null;
                      },
                    ),
                  },
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _input,
                    builder: (context, value, _) => TextField(
                      controller: _input,
                      maxLines: 6,
                      minLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _check(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText:
                            'Paste, type, or dictate the text to review.\nPress Enter (or tap Check) to get corrections.',
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.cancel, size: 20),
                                onPressed: () {
                                  _input.clear();
                                  context.read<GrammarProvider>().reset();
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _showMic
                  ? Padding(
                      key: const ValueKey('mic'),
                      padding: const EdgeInsets.only(top: 16),
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
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showMic = !_showMic);
                  },
                  icon: Icon(_showMic ? Icons.keyboard : Icons.mic_none),
                  label: Text(_showMic ? 'Hide mic' : 'Dictate'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: p.checking ? null : _check,
                  icon: p.checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: const Text('Check'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (p.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(p.error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            if (result != null)
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    _ResultCard(corrected: result.correctedText),
                    const SizedBox(height: 12),
                    if (result.changes.isEmpty)
                      const _NoChangesCard()
                    else ...[
                      Text('Changes made (${result.changes.length})',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ...result.changes
                          .map((c) => CorrectionCard(change: c)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.auto_fix_high, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Writing coach — grammar, punctuation, structure, tone.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.corrected});
  final String corrected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, size: 18, color: Colors.green),
              const SizedBox(width: 6),
              const Text('Corrected text',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: corrected));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(corrected),
        ],
      ),
    );
  }
}

class _NoChangesCard extends StatelessWidget {
  const _NoChangesCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [
          Icon(Icons.thumb_up_off_alt, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text('Looks good — no corrections needed.',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _CheckIntent extends Intent {
  const _CheckIntent();
}
