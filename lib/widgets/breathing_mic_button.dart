import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/stt_service.dart';

enum MicState { idle, listening, processing }

/// A microphone button with a polished recording experience: a soft
/// pulsing ring animates while the recognizer is listening, haptic
/// feedback confirms each state transition, and an inline callout
/// appears whenever the user has denied microphone access so they can
/// jump straight into Settings to re-enable it.
class BreathingMicButton extends StatefulWidget {
  const BreathingMicButton({
    super.key,
    required this.stt,
    required this.onPartial,
    required this.onFinal,
    this.localeId,
    this.size = 64,
  });

  final SttService stt;
  final void Function(String partial) onPartial;
  final void Function(String finalText) onFinal;
  final String? localeId;
  final double size;

  @override
  State<BreathingMicButton> createState() => _BreathingMicButtonState();
}

class _BreathingMicButtonState extends State<BreathingMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  MicState _state = MicState.idle;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == MicState.idle) {
      await _start();
    } else {
      await _stop();
    }
  }

  Future<void> _start() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _denied = true);
      return;
    }
    setState(() => _denied = false);
    final ok = await widget.stt.init();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _state = MicState.listening);
    _pulse.repeat(reverse: true);
    await widget.stt.start(
      localeId: widget.localeId,
      onPartial: widget.onPartial,
      onFinal: (text) {
        widget.onFinal(text);
        if (mounted) {
          setState(() => _state = MicState.idle);
          _pulse.stop();
          _pulse.reset();
          HapticFeedback.selectionClick();
        }
      },
    );
  }

  Future<void> _stop() async {
    HapticFeedback.lightImpact();
    setState(() => _state = MicState.processing);
    _pulse.stop();
    _pulse.reset();
    await widget.stt.stop();
    if (mounted) setState(() => _state = MicState.idle);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size + 24,
          height: widget.size + 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_state == MicState.listening)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulse.value * 0.35);
                    final opacity = 0.45 - (_pulse.value * 0.4);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: opacity.clamp(0, 1)),
                        ),
                      ),
                    );
                  },
                ),
              GestureDetector(
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _state == MicState.listening
                        ? Colors.redAccent
                        : color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    _state == MicState.listening ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: widget.size * 0.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_state == MicState.listening)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Listening… (auto-stops on silence)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        if (_denied)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _DenialCallout(
              text: 'Mic access is off. Open Settings to enable it.',
              onOpenSettings: openAppSettings,
            ),
          ),
      ],
    );
  }
}

class _DenialCallout extends StatelessWidget {
  const _DenialCallout({required this.text, required this.onOpenSettings});
  final String text;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.orange),
          const SizedBox(width: 6),
          Flexible(
              child: Text(text, style: const TextStyle(fontSize: 12))),
          TextButton(
              onPressed: onOpenSettings, child: const Text('Settings')),
        ],
      ),
    );
  }
}
